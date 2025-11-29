# frozen_string_literal: true

# Named ResearchThread to avoid conflict with Ruby's Thread class
class ResearchThread < ApplicationRecord
  include Sluggable

  slug :query

  self.table_name = "threads"

  belongs_to :insight, optional: true
  belongs_to :article, optional: true
  has_many :thread_articles, dependent: :destroy
  has_many :discovered_articles, through: :thread_articles, source: :article

  enum :status, { pending: 0, researched: 1 }

  # Source article for context (from insight or direct)
  def source_article
    article || insight&.article
  end
end
