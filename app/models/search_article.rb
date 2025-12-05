# frozen_string_literal: true

class SearchArticle < ApplicationRecord
  belongs_to :search
  belongs_to :article

  after_commit :broadcast_search, on: %i[create destroy]

  private

  def broadcast_search
    search.broadcast_self
  end
end
