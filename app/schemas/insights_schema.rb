# frozen_string_literal: true

class InsightsSchema < RubyLLM::Schema
  array :insights do
    object do
      string :title, description: "Short, memorable name for the insight (3-5 words)"
      string :body, description: "200-300 character insight or observation"
      string :snippet, description: "Relevant text snippet from the source article"
      array :threads, of: :string, description: "Research questions to explore further (2-4 questions)"
    end
  end
end
