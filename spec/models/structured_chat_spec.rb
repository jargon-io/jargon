# frozen_string_literal: true

require "rails_helper"

RSpec.describe StructuredChat do
  let(:valid_response) do
    { "insights" => [{ "title" => "Test", "body" => "Body", "snippet" => "Snippet" }] }
  end

  let(:invalid_response) do
    { "insights" => "not an array" }
  end

  let(:chat_double) { instance_double(RubyLLM::Chat) }

  before do
    allow(LLM).to receive(:chat).and_return(chat_double)
    allow(chat_double).to receive(:with_schema).and_return(chat_double)
    allow(chat_double).to receive(:with_instructions).and_return(chat_double)
    allow(chat_double).to receive(:add_message).and_return(chat_double)
  end

  describe "#ask" do
    it "returns content when response is valid" do
      allow(chat_double).to receive(:ask).and_return(
        instance_double(RubyLLM::Message, content: valid_response)
      )

      result = described_class.new(InsightsSchema).ask("test")

      expect(result).to eq(valid_response)
    end

    it "retries when response is invalid and succeeds" do
      call_count = 0
      allow(chat_double).to receive(:ask) do
        call_count += 1
        content = call_count == 1 ? invalid_response : valid_response
        instance_double(RubyLLM::Message, content:)
      end

      result = described_class.new(InsightsSchema).ask("test")

      expect(result).to eq(valid_response)
      expect(call_count).to eq(2)
      expect(chat_double).to have_received(:add_message).once
    end

    it "raises ValidationError after max retries" do
      allow(chat_double).to receive(:ask).and_return(
        instance_double(RubyLLM::Message, content: invalid_response)
      )

      expect { described_class.new(InsightsSchema).ask("test") }
        .to raise_error(StructuredChat::ValidationError)
    end

    it "passes instructions to chat when provided" do
      allow(chat_double).to receive(:ask).and_return(
        instance_double(RubyLLM::Message, content: valid_response)
      )

      described_class.new(InsightsSchema, instructions: "Be helpful").ask("test")

      expect(chat_double).to have_received(:with_instructions).with("Be helpful")
    end
  end
end
