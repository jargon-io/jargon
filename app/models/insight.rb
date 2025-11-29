# frozen_string_literal: true

class Insight < ApplicationRecord
  include Sluggable
  include Clusterable
  include Embeddable
  include NormalizesMarkup
  include Topicable

  slug -> { title.presence || "untitled" }

  normalizes_markup :body, :snippet

  embeddable :body

  has_neighbors :embedding

  belongs_to :article

  has_many :research_threads, dependent: :destroy

  enum :status, { pending: 0, complete: 1, failed: 2 }

  def topic_source_text
    "#{title}\n\n#{body}"
  end
end
