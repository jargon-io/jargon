# frozen_string_literal: true

module LLMHelpers
  # Default responses that cover all common schemas
  DEFAULT_LLM_RESPONSE = {
    "queries" => [],
    "insights" => [],
    "name" => "Default Name",
    "summary" => "Default summary",
    "title" => "Default Title",
    "body" => "Default body",
    "snippet" => "Default snippet"
  }.freeze

  def stub_llm_chat(responses = {})
    chat_double = instance_double(RubyLLM::Chat)

    allow(LLM).to receive(:chat).and_return(chat_double)
    allow(chat_double).to receive(:with_instructions).and_return(chat_double)
    allow(chat_double).to receive(:with_schema).and_return(chat_double)
    allow(chat_double).to receive(:with_model).and_return(chat_double)

    merged_response = DEFAULT_LLM_RESPONSE.merge(responses.fetch(:default, {}))
    allow(chat_double).to receive(:ask) do |_text|
      instance_double(RubyLLM::Message, content: merged_response)
    end

    chat_double
  end

  def stub_llm_embed(vectors = nil)
    vectors ||= Array.new(1536, 0.1)
    allow(LLM).to receive(:embed).and_return(
      instance_double(RubyLLM::Embedding, vectors:)
    )
  end

  def stub_llm
    stub_llm_chat
    stub_llm_embed
  end
end

RSpec.configure do |config|
  config.include LLMHelpers
end
