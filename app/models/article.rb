# frozen_string_literal: true

class Article < ApplicationRecord
  include Sluggable
  include Parentable
  include Embeddable
  include NormalizesMarkup
  include Linkable
  include SearchGeneratable

  slug -> { title.presence || "untitled" }

  before_validation :normalize_youtube_url

  synthesized_parent_attributes ->(_) { { url: nil, status: :complete } }

  normalizes_markup :summary

  embeddable :summary

  search_context -> { "Title: #{title}\nSummary: #{summary}" }

  has_neighbors :embedding

  has_many :insights, dependent: :destroy
  has_many :search_articles, dependent: :destroy
  has_many :containing_searches, through: :search_articles, source: :search

  enum :status, { pending: 0, complete: 1, failed: 2 }
  enum :content_type, { full: 0, partial: 1, video: 2, podcast: 3, paper: 4 }
  enum :origin, { manual: 0, discovered: 1 }

  validates :url, uniqueness: { allow_nil: true }
  validates :url, presence: true, unless: :parent?

  after_create_commit -> { IngestArticleJob.perform_later(self) }

  def image_url=(value)
    super(url_accessible?(value) ? value : nil)
  end

  def rolled_up_insights
    source_articles = parent? ? [self] + children.to_a : [self]

    root_ids = Insight.complete.roots.where(article: source_articles).pluck(:id)
    parent_ids = Insight.complete.children.where(article: source_articles).pluck(:parent_id)

    Insight.where(id: (root_ids + parent_ids).uniq)
  end

  def regenerate_metadata!
    return unless parent? && children.any?

    update!(ParentSynthesizer.new(children).synthesize)

    generate_embedding!
    generate_searches!

    AddLinksJob.set(wait: 30.seconds).perform_later(self)
  end

  private

  def normalize_youtube_url
    return unless url.present? && YoutubeClient.youtube_url?(url)

    self.url = YoutubeClient.normalize_url(url)
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
