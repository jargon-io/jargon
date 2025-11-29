# frozen_string_literal: true

module Topicable
  extend ActiveSupport::Concern

  TOPIC_INSTRUCTIONS = <<~PROMPT
    Generate 3-5 cross-disciplinary topic phrases that bridge this content to other fields.

    NOT follow-up questions or deeper dives into the same subject.
    Instead, find conceptual bridges to completely different domains:
    - Analogous mechanisms (same underlying principle elsewhere)
    - Structural parallels (similar patterns in other fields)
    - Historical precedents (past innovations with similar tradeoffs)

    Example: For an article about "efficient LLM architectures":
    BAD: "Future of AI hardware", "Scaling laws in deep learning"
    GOOD: "Compression in biological memory", "Modularity in cathedral architecture", "Resource allocation in ant colonies"

    Each phrase: 3-6 words, capitalized, concrete enough to search for.
  PROMPT

  included do
    has_many :topics, as: :topicable, dependent: :destroy
  end

  def generate_topics!
    return if topic_source_text.blank?

    response = LLM.chat
                  .with_schema(TopicsSchema)
                  .with_instructions(TOPIC_INSTRUCTIONS)
                  .ask(topic_source_text)

    topics.destroy_all
    response.content["topics"].each do |phrase|
      topic = topics.create!(phrase:)
      topic.generate_embedding!
    end
  end

  def topic_source_text
    raise NotImplementedError, "#{self.class} must implement #topic_source_text"
  end
end
