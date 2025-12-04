# frozen_string_literal: true

class Article < ApplicationRecord
  include Sluggable
  include Parentable
  include Embeddable
  include NormalizesMarkup
  include Linkable
  include SearchGeneratable
  include Broadcastable

  slug -> { title }

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
  validates :url, presence: true, unless: :has_children?

  after_create_commit -> { IngestArticleJob.perform_later(self) }

  def image_url=(value)
    super(url_accessible?(value) ? value : nil)
  end

  def rolled_up_insights
    source_articles = has_children? ? [self] + children.to_a : [self]

    root_ids = Insight.complete.roots.where(article: source_articles).pluck(:id)
    parent_ids = Insight.complete.children.where(article: source_articles).pluck(:parent_id)

    Insight.where(id: (root_ids + parent_ids).uniq).includes(:article)
  end

  def regenerate_metadata!
    return unless has_children?

    update!(ParentSynthesizer.new(children).synthesize)

    generate_embedding!
    generate_searches!

    AddLinksJob.set(wait: 30.seconds).perform_later(self)
  end

  def find_related_items
    return [] if embedding.blank?

    SimilarItemsQuery.new(embedding:, limit: 8, exclude: [self] + insights.to_a).call
  end

  def record_error!(exception)
    update!(
      status: :failed,
      last_error: {
        class: exception.class.name,
        message: exception.message.truncate(500),
        occurred_at: Time.current.iso8601
      }.to_json
    )
  end

  def parsed_error
    return nil if last_error.blank?

    JSON.parse(last_error).with_indifferent_access
  rescue JSON::ParserError
    { class: "Unknown", message: last_error }
  end

  def error_category
    return nil unless failed? && parsed_error

    case parsed_error[:class]
    when /Timeout|Net::|Socket|Errno::/ then :network
    when /Paywall|Forbidden/ then :paywall
    when /Blocked|Captcha|RateLimit/ then :blocked
    else :unknown
    end
  end

  def user_friendly_error_message
    {
      network: "Could not reach the website.",
      paywall: "Content is behind a paywall.",
      blocked: "Access was blocked by the website."
    }[error_category] || "An unexpected error occurred."
  end

  def broadcast_to_parents
    containing_searches.find_each(&:broadcast_self)
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
