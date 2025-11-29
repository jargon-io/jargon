# frozen_string_literal: true

class ResearchThreadJob < ApplicationJob
  def perform(research_thread_id)
    thread = ResearchThread.find(research_thread_id)

    source_article = thread.source_article
    insight = thread.insight

    instructions = <<~INSTRUCTIONS
      You will be provided with context about an article and a research question.

      Your task is to search the web for interesting articles related to
      the research question given the provided context.

      ONLY return HTML web sources - no PDFs or other downloadable files.

      Try to find 2-4 pages that offer different perspectives or insights.
    INSTRUCTIONS

    prompt = <<~PROMPT
      Article: #{source_article&.title}

      Article summary: #{source_article&.summary}

      #{"Insight: #{insight.body}" if insight}

      Research question: #{thread.query}
    PROMPT

    chat = RubyLLM.chat
                  .with_instructions(instructions)
                  .with_tool(ExaSearchTool.new)

    chat.ask(prompt)

    articles = chat.with_schema(SelectedArticlesSchema)
                   .ask("Respond with articles in JSON format.")
                   .content["articles"] || []

    articles.each do |data|
      url = data["url"]

      next if url.blank?

      article = Article.find_or_initialize_by(url:) do |a|
        a.title = data["title"]
      end

      is_new = article.new_record?

      article.save! if is_new

      thread.thread_articles.find_or_create_by!(article:) do |ta|
        ta.relevance_note = data["relevance_note"]
      end

      IngestArticleJob.perform_later(url) if is_new

      broadcast_article(thread, article, data["relevance_note"])
    end

    thread.update!(status: :researched)

    broadcast_complete(thread)
  rescue StandardError => e
    Rails.logger.error("ResearchThreadJob failed: #{e.message}")
    raise e
  end

  private

  def broadcast_article(thread, article, relevance_note)
    Turbo::StreamsChannel.broadcast_remove_to(
      "research_thread_#{thread.id}",
      target: "thread_articles_loading"
    )

    Turbo::StreamsChannel.broadcast_append_to(
      "research_thread_#{thread.id}",
      target: "thread_articles",
      partial: "articles/article",
      locals: { article:, relevance_note: }
    )
  end

  def broadcast_complete(thread)
    Turbo::StreamsChannel.broadcast_replace_to(
      "research_thread_#{thread.id}",
      target: "thread_status",
      html: '<span class="text-green-600">Research complete</span>'
    )
  end
end
