# frozen_string_literal: true

module Embeddable
  extend ActiveSupport::Concern

  class_methods do
    attr_reader :embeddable_field

    def embeddable(field)
      @embeddable_field = field
    end
  end

  def generate_embedding!
    field = self.class.embeddable_field

    raise "No embeddable field defined for #{self.class}" unless field

    text = send(field)
    return if text.blank?

    embedding = LLM.embed(text)

    update!(embedding: embedding.vectors)
  end
end
