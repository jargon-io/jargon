# frozen_string_literal: true

RubyLLM.configure do |config|
  config.openrouter_api_key = ENV.fetch("OPENROUTER_API_KEY") { Rails.application.credentials.openrouter_api_key }
  config.default_model = "google/gemini-2.5-flash"
  config.default_embedding_model = "openai/text-embedding-3-small"
end
