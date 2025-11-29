# frozen_string_literal: true

class InsightClusterSchema < RubyLLM::Schema
  string :title, description: "The canonical insight as a concise title (5-10 words)"
  string :body, description: "The distilled insight capturing all nuance from the variations (2-4 sentences)"
  string :snippet, description: "A synthesized key quote that captures the essence (1-2 sentences, quotable)"
end
