# frozen_string_literal: true

class ResearchThread < ApplicationRecord
  include Sluggable

  slug :query

  self.table_name = "threads"

  belongs_to :subject, polymorphic: true, optional: true

  has_many :thread_articles, dependent: :destroy
  has_many :discovered_articles, through: :thread_articles, source: :article

  enum :status, { pending: 0, researched: 1 }

  def insight
    subject if subject.is_a?(Insight)
  end

  def source_article
    case subject
    when Article then subject
    when Insight then subject.article
    end
  end
end
