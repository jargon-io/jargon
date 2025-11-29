# frozen_string_literal: true

class InsightClusterSchema < RubyLLM::Schema
  string :title, description: "The canonical insight as a concise title (5-10 words)"
  string :body, description: "Distilled insight (2-4 sentences). Use <strong> for emphasis. State directly."
  string :snippet, description: "Synthesized quote (1-2 sentences). May use <strong> and ellipses."
end
