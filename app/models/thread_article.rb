# frozen_string_literal: true

class ThreadArticle < ApplicationRecord
  belongs_to :research_thread
  belongs_to :article
end
