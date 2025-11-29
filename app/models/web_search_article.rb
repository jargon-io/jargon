# frozen_string_literal: true

class WebSearchArticle < ApplicationRecord
  belongs_to :web_search
  belongs_to :article
end
