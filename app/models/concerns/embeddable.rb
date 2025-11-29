# frozen_string_literal: true

module Embeddable
  extend ActiveSupport::Concern

  MODEL = "openai/text-embedding-3-small"

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

    embedding = RubyLLM.embed(
      text,
      model: MODEL,
      provider: :openrouter,
      assume_model_exists: true
    )

    update!(embedding: embedding.vectors)
  end
end
