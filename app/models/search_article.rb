# frozen_string_literal: true

class SearchArticle < ApplicationRecord
  belongs_to :search
  belongs_to :article
end
