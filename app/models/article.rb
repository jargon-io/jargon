# frozen_string_literal: true

class Article < ApplicationRecord
  enum :status, { pending: 0, complete: 1, failed: 2 }

  validates :url, presence: true, uniqueness: true

  def to_param
    nanoid
  end
end
