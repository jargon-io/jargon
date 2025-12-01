# frozen_string_literal: true

class GenerateInsightsJob < ApplicationJob
  def perform(article)
    return if article.text.blank?

    prompt = build_prompt(article)

    response = LLM.chat
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
      insight.find_similar_and_absorb!
      insight.generate_searches!

      broadcast_insight(article, insight)
    end

    # Queue link generation after delay to allow batch insights to be available as targets
    article.insights.complete.each do |insight|
      AddLinksJob.set(wait: 30.seconds).perform_later(insight)
    end

    notify_pending_searches(article)
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
      PROMPT
    elsif article.video? || article.podcast?
      <<~PROMPT
        Extract key insights from this transcript. For each:
        - title: Short, memorable name (3-5 words)
        - body: 200-300 char insight. Use <strong> for 1-2 key terms. State the idea directly.
        - snippet: Edit the source text for clarity and readability. Fix grammar, punctuation, and
          remove filler words (um, uh, like, you know). Use ... to tighten. May bold key phrases with <strong>.

        Note: This is a transcript, so focus on explicitly stated ideas. Clean up speech artifacts.
      PROMPT
    else
      <<~PROMPT
        Extract key insights from this article. For each:
        - title: Short, memorable name (3-5 words)
        - body: 200-300 char insight. Use <strong> for 1-2 key terms. State the idea directly.
        - snippet: Source excerpt. Use ... to tighten. May bold key phrases with <strong>.
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
      partial: "insights/broadcast_insight",
      locals: { insight: }
    )
  end

  def notify_pending_searches(article)
    SearchArticle.where(article:).includes(:search).find_each do |sa|
      search = sa.search
      next unless search.searching?

      HydrateSearchJob.perform_later(search) if search.all_insights_ready?
    end
  end
end
