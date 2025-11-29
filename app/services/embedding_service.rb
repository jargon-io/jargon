# frozen_string_literal: true

class EmbeddingService
  def self.generate(text)
    return nil if text.blank?

    result = RubyLLM.embed(
      text,
      model: "openai/text-embedding-3-small",
      provider: :openrouter,
      assume_model_exists: true
    )

    result.vectors
  end
end
