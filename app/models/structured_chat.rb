# frozen_string_literal: true

class StructuredChat
  class ValidationError < StandardError; end

  MAX_RETRIES = 2

  def initialize(schema, instructions: nil)
    @schema = schema
    @instructions = instructions
    @chat = build_chat
  end

  def ask(message)
    (MAX_RETRIES + 1).times do |attempt|
      response = @chat.ask(message)
      content = response.content

      validate!(content)
      return content
    rescue JSON::Schema::ValidationError => e
      raise ValidationError, e.message if attempt >= MAX_RETRIES

      Rails.logger.warn("StructuredChat validation failed (attempt #{attempt + 1}): #{e.message}")
      @chat.add_message(role: :user, content: error_feedback(e))
    end
  end

  private

  def build_chat
    chat = LLM.chat.with_schema(@schema)
    chat = chat.with_instructions(@instructions) if @instructions
    chat
  end

  def validate!(content)
    json_schema = @schema.new.to_json_schema[:schema]
    JSON::Validator.validate!(json_schema, content)
  end

  def error_feedback(error)
    <<~PROMPT
      Your response did not match the required schema:
      #{error.message}

      Please try again with a corrected response.
    PROMPT
  end
end
