# frozen_string_literal: true

RubyLLM.configure do |config|
  # Provider API keys - set only the ones you use
  config.openrouter_api_key = ENV.fetch("OPENROUTER_API_KEY", nil)
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY", nil)
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
  config.gemini_api_key = ENV.fetch("GEMINI_API_KEY", nil)

  # Model defaults - override via env vars
  config.default_model = ENV.fetch("LLM_MODEL", "google/gemini-2.5-flash")
  config.default_embedding_model = ENV.fetch("EMBEDDING_MODEL", "openai/text-embedding-3-small")
end

# Provider configuration for assume_model_exists support (needed for new models not in registry)
LLM_PROVIDER = ENV.fetch("LLM_PROVIDER", "openrouter").to_sym
EMBEDDING_PROVIDER = ENV.fetch("EMBEDDING_PROVIDER", "openrouter").to_sym

module LLM
  def self.chat
    RubyLLM.chat(provider: LLM_PROVIDER, assume_model_exists: true)
  end

  def self.embed(text)
    RubyLLM.embed(text, provider: EMBEDDING_PROVIDER, assume_model_exists: true)
  end
end
