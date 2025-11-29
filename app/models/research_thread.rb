# frozen_string_literal: true

class ResearchThread < ApplicationRecord
  include Sluggable

  slug :query

  self.table_name = "threads"

  belongs_to :insight, optional: true
  belongs_to :article, optional: true

  has_many :thread_articles, dependent: :destroy
  has_many :discovered_articles, through: :thread_articles, source: :article

  enum :status, { pending: 0, researched: 1 }

  def source_article
    article || insight&.article
  end
end
