# frozen_string_literal: true

class ResearchThreadJob < ApplicationJob
  def perform(research_thread_id)
    thread = ResearchThread.find(research_thread_id)

    query = generate_search_query(thread)
    results = ExaClient.new.search(query:)["results"] || []
    articles = filter_results(thread, results)

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
      broadcast_article(thread, article)
    end

    thread.update!(status: :researched)
    broadcast_complete(thread)
  rescue StandardError => e
    Rails.logger.error("ResearchThreadJob failed: #{e.message}")
    raise e
  end

  private

  def generate_search_query(thread)
    context = <<~CONTEXT
      Article: #{thread.source_article&.title}
      Summary: #{thread.source_article&.summary}
      #{"Insight: #{thread.insight.body}" if thread.insight}
      Research question: #{thread.query}
    CONTEXT

    LLM.chat
           .with_instructions("Generate a concise search query (5-10 words) to find articles related to the research question. Return only the query, nothing else.")
           .ask(context)
           .content
  end

  def filter_results(thread, results)
    return [] if results.empty?

    candidates = results.take(10).map do |r|
      { url: r["url"], title: r["title"] }
    end

    prompt = <<~PROMPT
      Research question: #{thread.query}

      Context: #{thread.source_article&.title}

      Candidate articles:
      #{candidates.map { |c| "- #{c[:title]} (#{c[:url]})" }.join("\n")}

      Select 2-4 articles that offer different perspectives. Exclude PDFs and non-article pages.
    PROMPT

    LLM.chat
           .with_schema(SelectedArticlesSchema)
           .ask(prompt)
           .content["articles"] || []
  end

  def broadcast_article(thread, article)
    Turbo::StreamsChannel.broadcast_remove_to(
      "research_thread_#{thread.id}",
      target: "thread_articles_loading"
    )

    Turbo::StreamsChannel.broadcast_append_to(
      "research_thread_#{thread.id}",
      target: "articles",
      partial: "articles/article",
      locals: { article: }
    )
  end

  def broadcast_complete(thread)
    Turbo::StreamsChannel.broadcast_remove_to(
      "research_thread_#{thread.id}",
      target: "thread_loading"
    )
  end
end
