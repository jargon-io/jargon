# frozen_string_literal: true

class GenerateInsightsJob < ApplicationJob
  MODEL = "google/gemini-2.5-flash"

  def perform(article_id)
    article = Article.find(article_id)

    prompt = <<~PROMPT
      Analyze this article and extract key insights. For each insight:
      - title: A short, memorable name (3-5 words)
      - body: A 200-300 character insight or observation
      - snippet: The relevant text from the article that supports this insight
      - threads: 2-4 research questions that could be explored further
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

      generate_embedding(insight)

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

  def generate_embedding(insight)
    return if insight.body.blank?

    embedding = RubyLLM.embed(insight.body,
                              model: "openai/text-embedding-3-small",
                              provider: :openrouter,
                              assume_model_exists: true)

    insight.update!(embedding: embedding.vectors)
  end
end
