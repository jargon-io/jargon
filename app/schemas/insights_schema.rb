# frozen_string_literal: true

class InsightsSchema < RubyLLM::Schema
  array :insights do
    object do
      string :title, description: "Short, memorable name for the insight (3-5 words)"
      string :body, description: "200-300 character insight. Use <strong> for 1-2 key terms. State directly, not 'this insight is about...'"
      string :snippet, description: "Relevant excerpt from source. Use ellipses (...) to tighten. May use <strong> for emphasis."
    end
  end
end
