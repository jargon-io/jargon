# frozen_string_literal: true

class AddLinksJob < ApplicationJob
  queue_as :default

  LINK_PATTERN = ApplicationHelper::INTERNAL_LINK_PATTERN

  FIELDS = {
    Article => [:summary],
    Insight => %i[body snippet]
  }.freeze

  def perform(record)
    @record = record
    @fields = FIELDS[record.class]
    @linkable_insights = @record.linkable_insights
    @valid_keys = @linkable_insights.to_set(&:slug_with_class)

    return if @fields.blank? || @valid_keys.empty?

    @fields.each do |field|
      content = @record.send(field)
      next if content.blank?

      linked_content = add_links_to_content(content)
      next unless linked_content

      @record.update(field => linked_content)
    end
  end

  private

  def add_links_to_content(content)
    prompt = <<~PROMPT
      Add internal links to this content where relevant. Use markdown link syntax: [link text](insight:slug)

      Rules:
      - Only link to insights from the available targets below
      - Link text should be natural phrases from the existing content
      - Don't change any words - only add link markup around existing phrases
      - Don't add links if none are relevant
      - Return the content with links added, or unchanged if no links fit

      Available link targets:
      #{@linkable_insights.map { |i| "- [insight:#{i.slug}] #{i.title}" }.join("\n")}

      Content to process:
      #{content}
    PROMPT

    response = LLM.chat.ask(prompt)
    linked = normalize_markup(response.content)

    return nil unless valid_linked_content?(content, linked)

    linked
  end

  def valid_linked_content?(original, linked)
    # Strip links from both and compare plaintext
    original_plain = strip_links(original)
    linked_plain = strip_links(linked)

    return false unless original_plain == linked_plain

    # Validate all links point to valid targets
    linked.scan(LINK_PATTERN).all? do |match|
      key = "#{match[1]}:#{match[2]}"
      @valid_keys.include?(key)
    end
  end

  def strip_links(text)
    text.gsub(LINK_PATTERN, '\1')
  end

  def normalize_markup(text)
    text.gsub(/\*\*([^*]+)\*\*/, '<strong>\1</strong>')
  end
end
