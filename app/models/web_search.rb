# frozen_string_literal: true

class WebSearch < ApplicationRecord
  enum :status, { pending: 0, complete: 1 }

  has_many :web_search_articles, dependent: :destroy
  has_many :articles, through: :web_search_articles
end
