# frozen_string_literal: true

class Insight < ApplicationRecord
  include Sluggable
  include Parentable
  include Embeddable
  include NormalizesMarkup
  include Linkable
  include ResearchThreadGeneratable

  slug -> { title.presence || "untitled" }

  synthesized_parent_attributes ->(_) { { article: nil, status: :complete } }

  normalizes_markup :body, :snippet

  embeddable :body

  has_neighbors :embedding

  belongs_to :article, optional: true
  validates :article, presence: true, unless: :parent?

  enum :status, { pending: 0, complete: 1, failed: 2 }

  after_destroy_commit -> { CleanupDeadLinksJob.perform_later(slug) }

  def research_thread_context
    "Title: #{title}\nBody: #{body}\nSnippet: #{snippet}"
  end

  def sibling_insights
    return [] if embedding.blank?

    if parent?
      article_ids = children.includes(:article)
                            .flat_map { |c| [c.article&.id, c.article&.parent_id] }
                            .compact
                            .uniq

      excluded_ids = children.pluck(:id) + [id]
    else
      article_ids = [article_id].compact

      excluded_ids = [id]
    end

    return [] if article_ids.empty?

    root_ids = Insight.complete.roots.where(article_id: article_ids).pluck(:id)
    parent_ids = Insight.complete.children.where(article_id: article_ids).pluck(:parent_id)

    Insight.where(id: root_ids + parent_ids)
           .where.not(id: excluded_ids)
           .distinct
           .nearest_neighbors(:embedding, embedding, distance: "cosine")
           .to_a
  end

  def regenerate_metadata!
    return unless parent?

    child_insights = children.to_a
    return if child_insights.empty?

    context = child_insights.map { |i| format_for_synthesis(i) }.join("\n\n---\n\n")

    prompt = <<~PROMPT
      These are variations of the same insight from different sources. Synthesize into ONE canonical insight:
      - Captures the core idea directly (not "this cluster is about...")
      - Incorporates nuance and detail from all variations
      - Use <strong> for 1-2 key terms
      - Snippet may use ellipses (...) to tighten

      #{context}
    PROMPT

    response = LLM.chat
                  .with_schema(InsightClusterSchema)
                  .ask(prompt)

    update!(
      title: response.content["title"],
      body: response.content["body"],
      snippet: response.content["snippet"]
    )

    generate_embedding!
    generate_research_threads!

    AddLinksJob.set(wait: 30.seconds).perform_later("Insight", id)
  rescue StandardError => e
    Rails.logger.error("Insight parent metadata generation failed: #{e.message}")
  end

  private

  def format_for_synthesis(insight)
    <<~INSIGHT
      Title: #{insight.title}
      Body: #{insight.body}
      Snippet: #{insight.snippet}
    INSIGHT
  end
end
