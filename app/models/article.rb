# frozen_string_literal: true

class Article < ApplicationRecord
  validates :title, presence: true
  validates :url, presence: true
  validates :text, presence: true
end
