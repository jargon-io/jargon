# frozen_string_literal: true

class Cluster < ApplicationRecord
  include Sluggable
  include Embeddable
  include NormalizesMarkup
  include Linkable
  include ResearchThreadGeneratable

  slug -> { name.presence || "untitled" }

  normalizes_markup :name, :summary, :body, :snippet

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

    prompt = <<~PROMPT
      These are the same article from different sources. Generate:
      - A clean, canonical title (without source names like 'PubMed' or 'Nature')
      - A summary that states the key idea directly (not "this cluster is about...")
      - Use <strong> for 1-2 key terms

      #{context}
    PROMPT

    response = LLM.chat
                      .with_schema(ClusterMetadataSchema)
                      .ask(prompt)

    update!(
      name: response.content["name"],
      summary: response.content["summary"],
      image_url: select_best_image(article_members),
      status: :complete
    )

    generate_embedding!
    generate_research_threads!
    AddLinksJob.set(wait: 30.seconds).perform_later("Cluster", id)
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
      name: response.content["title"],
      body: response.content["body"],
      snippet: response.content["snippet"],
      status: :complete
    )
    generate_embedding!
    generate_research_threads!
    AddLinksJob.set(wait: 30.seconds).perform_later("Cluster", id)
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

  def research_thread_context
    if clusterable_type == "Insight"
      "Title: #{name}\nBody: #{body}\nSnippet: #{snippet}"
    else
      "Title: #{name}\nSummary: #{summary}"
    end
  end

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
