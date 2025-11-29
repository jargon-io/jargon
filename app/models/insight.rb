# frozen_string_literal: true

class Insight < ApplicationRecord
  include Sluggable
  include Clusterable
  include Embeddable

  slug -> { title.presence || "untitled" }

  embeddable :body

  has_neighbors :embedding

  belongs_to :article

  has_many :research_threads, dependent: :destroy

  enum :status, { pending: 0, complete: 1, failed: 2 }
end
