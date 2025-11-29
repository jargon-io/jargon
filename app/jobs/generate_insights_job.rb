# frozen_string_literal: true

class GenerateInsightsJob < ApplicationJob
  MODEL = "google/gemini-2.5-flash"

  def perform(article_id)
    article = Article.find(article_id)

    return if article.text.blank?

    prompt = build_prompt(article)

    response = RubyLLM.chat
                      .with_model(MODEL)
                      .with_instructions(prompt)
                      .with_schema(InsightsSchema)
                      .ask(article.text)

    insights_data = response.content["insights"]

    insights_data.each do |data|
      insight = article.insights.create!(
        title: data["title"],
        body: data["body"],
        snippet: data["snippet"],
        status: :complete
      )

      insight.generate_embedding!
      insight.cluster_if_similar!

      data["queries"].each do |query|
        insight.research_threads.create!(query:)
      end

      broadcast_insight(article, insight)
    end
  rescue StandardError => e
    Rails.logger.error("GenerateInsightsJob failed: #{e.message}")
    raise e
  end

  private

  def build_prompt(article)
    if article.partial?
      <<~PROMPT
        This is partial content (abstract, description, or preview). Infer ONE key insight:
        - title: Short, memorable name (3-5 words)
        - body: 200-300 char insight. Use <strong> for 1-2 key terms. State what this is likely about.
        - snippet: Use available text. May use ... to tighten.
        - queries: 2-4 research questions to explore the topic further
      PROMPT
    elsif article.video? || article.podcast?
      <<~PROMPT
        Extract key insights from this transcript. For each:
        - title: Short, memorable name (3-5 words)
        - body: 200-300 char insight. Use <strong> for 1-2 key terms. State the idea directly.
        - snippet: Source excerpt. Use ... to tighten. May bold key phrases with <strong>.
        - queries: 2-4 research questions to explore further

        Note: This is a transcript, so focus on explicitly stated ideas rather than inferring.
      PROMPT
    else
      <<~PROMPT
        Extract key insights from this article. For each:
        - title: Short, memorable name (3-5 words)
        - body: 200-300 char insight. Use <strong> for 1-2 key terms. State the idea directly.
        - snippet: Source excerpt. Use ... to tighten. May bold key phrases with <strong>.
        - queries: 2-4 research questions to explore further
      PROMPT
    end
  end

  def broadcast_insight(article, insight)
    Turbo::StreamsChannel.broadcast_remove_to(
      "article_#{article.id}_insights",
      target: "insights_loading"
    )

    Turbo::StreamsChannel.broadcast_append_to(
      "article_#{article.id}_insights",
      target: "insights",
      partial: "insights/insight",
      locals: { insight:, suppress_source: true }
    )
  end
end
