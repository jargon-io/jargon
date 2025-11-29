# frozen_string_literal: true

class GenerateInsightsJob < ApplicationJob
  MODEL = "google/gemini-2.5-flash"

  def perform(article_id)
    article = Article.find(article_id)

    prompt = <<~PROMPT
      Extract key insights from this article. For each:
      - title: Short, memorable name (3-5 words)
      - body: 200-300 char insight. Use <strong> for 1-2 key terms. State the idea directly.
      - snippet: Source excerpt. Use ... to tighten. May bold key phrases with <strong>.
      - queries: 2-4 research questions to explore further
    PROMPT

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

  def broadcast_insight(article, insight)
    Turbo::StreamsChannel.broadcast_remove_to(
      "article_#{article.id}_insights",
      target: "insights_loading"
    )

    Turbo::StreamsChannel.broadcast_after_to(
      "article_#{article.id}_insights",
      target: "insights",
      partial: "insights/insight",
      locals: { insight:, article: }
    )
  end
end
