# frozen_string_literal: true

class Article < ApplicationRecord
  has_many :insights, dependent: :destroy
  has_many :thread_articles, dependent: :destroy
  has_many :research_threads, through: :thread_articles

  enum :status, { pending: 0, complete: 1, failed: 2 }

  validates :url, presence: true, uniqueness: true

  def to_param
    nanoid
  end
end
