# frozen_string_literal: true

class Article < ApplicationRecord
  include Sluggable

  slug -> { title.presence || "untitled" }

  has_neighbors :embedding

  has_many :insights, dependent: :destroy
  has_many :thread_articles, dependent: :destroy
  has_many :research_threads, through: :thread_articles
  has_many :web_search_articles, dependent: :destroy

  enum :status, { pending: 0, complete: 1, failed: 2 }

  validates :url, presence: true, uniqueness: true
end
