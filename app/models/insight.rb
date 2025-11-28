# frozen_string_literal: true

class Insight < ApplicationRecord
  has_neighbors :embedding

  belongs_to :article
  has_many :research_threads, dependent: :destroy

  enum :status, { pending: 0, complete: 1, failed: 2 }

  def to_param
    nanoid
  end
end
