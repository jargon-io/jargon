# frozen_string_literal: true

class Topic < ApplicationRecord
  include Embeddable

  embeddable :phrase

  has_neighbors :embedding

  belongs_to :topicable, polymorphic: true

  validates :phrase, presence: true
end
