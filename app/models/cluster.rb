# frozen_string_literal: true

class Cluster < ApplicationRecord
  include Sluggable
  include Embeddable

  slug -> { name.presence || "untitled" }

  embeddable :embeddable_text

  has_neighbors :embedding

  def embeddable_text
    clusterable_type == "Insight" ? body : summary
  end

  has_many :cluster_memberships, dependent: :destroy
  has_many :articles, through: :cluster_memberships, source: :clusterable, source_type: "Article"
  has_many :insights, through: :cluster_memberships, source: :clusterable, source_type: "Insight"

  enum :status, { pending: 0, complete: 1 }

  scope :for_articles, -> { where(clusterable_type: "Article") }
  scope :for_insights, -> { where(clusterable_type: "Insight") }

  validates :clusterable_type, presence: true, inclusion: { in: %w[Article Insight] }

  def members
    cluster_memberships.includes(:clusterable).map(&:clusterable)
  end

  def member_count
    cluster_memberships.count
  end

  def generate_metadata!
    case clusterable_type
    when "Article"
      generate_article_metadata!
    when "Insight"
      generate_insight_metadata!
    end
  end

  def generate_article_metadata!
    article_members = members.select { |m| m.is_a?(Article) }
    return update!(status: :complete) if article_members.empty?

    context = article_members.map { |a| format_article_for_metadata(a) }.join("\n\n---\n\n")

    response = RubyLLM.chat
                      .with_schema(ClusterMetadataSchema)
                      .ask("These are the same article from different sources. Generate a clean, canonical title (without source names like 'PubMed' or 'Nature') and a brief summary:\n\n#{context}")

    update!(
      name: response.content["name"]&.titleize,
      summary: response.content["summary"],
      image_url: select_best_image(article_members),
      status: :complete
    )

    generate_embedding!
  end

  def format_article_for_metadata(article)
    <<~ARTICLE
      Title: #{article.title}
      Summary: #{article.summary}
      Author: #{article.author.presence || 'N/A'}
    ARTICLE
  end

  def select_best_image(articles)
    articles.find { |a| a.image_url.present? }&.image_url
  end

  def generate_insight_metadata!
    insight_members = members.select { |m| m.is_a?(Insight) }
    return update!(status: :complete) if insight_members.empty?

    context = insight_members.map { |i| format_insight_for_metadata(i) }.join("\n\n---\n\n")

    prompt = <<~PROMPT
      These are variations of the same insight from different sources. Synthesize them into ONE canonical insight that:
      - Captures the core idea directly (not "this cluster is about...")
      - Incorporates nuance and detail from all variations
      - Reads as a standalone insight, not a summary of a collection

      #{context}
    PROMPT

    response = RubyLLM.chat
                      .with_model(MODEL)
                      .with_schema(InsightClusterSchema)
                      .ask(prompt)

    update!(
      name: response.content["title"],
      body: response.content["body"],
      snippet: response.content["snippet"],
      status: :complete
    )
    generate_embedding!
  rescue StandardError => e
    Rails.logger.error("Insight cluster metadata generation failed: #{e.message}")
    update!(status: :complete)
  end

  def format_insight_for_metadata(insight)
    <<~INSIGHT
      Title: #{insight.title}
      Body: #{insight.body}
      Snippet: #{insight.snippet}
    INSIGHT
  end

  alias regenerate_metadata! generate_metadata!

  private

  def format_member(member)
    case member
    when Article
      "Article: #{member.title}\n#{member.summary}"
    when Insight
      "Insight: #{member.title}\n#{member.body}"
    end
  end
end
