# frozen_string_literal: true

class Article < ApplicationRecord
  include Sluggable
  include Clusterable
  include Embeddable
  include NormalizesMarkup

  slug -> { title.presence || "untitled" }

  normalizes_markup :summary

  embeddable :summary

  has_neighbors :embedding

  has_many :insights, dependent: :destroy
  has_many :thread_articles, dependent: :destroy
  has_many :research_threads, through: :thread_articles
  has_many :web_search_articles, dependent: :destroy

  enum :status, { pending: 0, complete: 1, failed: 2 }
  enum :content_type, { full: 0, partial: 1, video: 2, podcast: 3 }

  validates :url, presence: true, uniqueness: true

  def image_url=(value)
    super(url_accessible?(value) ? value : nil)
  end

  private

  def url_accessible?(url)
    return false if url.blank?

    response = HTTPX.head(url, timeout: { operation_timeout: 5 })
    response.status < 400
  rescue StandardError
    false
  end
end
