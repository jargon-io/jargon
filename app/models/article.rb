# frozen_string_literal: true

class Article < ApplicationRecord
  include Sluggable
  include Parentable
  include Embeddable
  include NormalizesMarkup
  include Linkable
  include ResearchThreadGeneratable

  slug -> { title.presence || "untitled" }
  synthesized_parent_attributes ->(_) { { url: nil, status: :complete } }

  normalizes_markup :summary

  embeddable :summary

  has_neighbors :embedding

  has_many :insights, dependent: :destroy
  has_many :thread_articles, dependent: :destroy
  has_many :discovered_research_threads, through: :thread_articles, source: :research_thread
  has_many :web_search_articles, dependent: :destroy

  enum :status, { pending: 0, complete: 1, failed: 2 }
  enum :content_type, { full: 0, partial: 1, video: 2, podcast: 3, paper: 4 }

  validates :url, uniqueness: { allow_nil: true }
  validates :url, presence: true, unless: :parent?

  def image_url=(value)
    super(url_accessible?(value) ? value : nil)
  end

  def research_thread_context
    "Title: #{title}\nSummary: #{summary}"
  end

  def rolled_up_insights
    source_articles = parent? ? [self] + children.to_a : [self]

    root_ids = Insight.complete.roots.where(article: source_articles).pluck(:id)
    parent_ids = Insight.complete.children.where(article: source_articles).pluck(:parent_id)

    Insight.where(id: (root_ids + parent_ids).uniq)
  end

  def regenerate_metadata!
    return unless parent?

    child_articles = children.to_a
    return if child_articles.empty?

    context = child_articles.map { |a| format_for_synthesis(a) }.join("\n\n---\n\n")

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
      title: response.content["name"],
      summary: response.content["summary"],
      image_url: select_best_image(child_articles)
    )

    generate_embedding!
    generate_research_threads!
    AddLinksJob.set(wait: 30.seconds).perform_later("Article", id)
  end

  private

  def format_for_synthesis(article)
    <<~ARTICLE
      Title: #{article.title}
      Summary: #{article.summary}
      Author: #{article.author.presence || 'N/A'}
    ARTICLE
  end

  def select_best_image(articles)
    articles.find { |a| a.image_url.present? }&.image_url
  end

  def url_accessible?(url)
    return false if url.blank?

    response = HTTPX.plugin(:follow_redirects).head(url, timeout: { operation_timeout: 5 })
    return false unless response.status == 200

    content_type = response.headers["content-type"].to_s
    content_type.start_with?("image/")
  rescue StandardError
    false
  end
end
