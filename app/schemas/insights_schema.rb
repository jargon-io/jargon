# frozen_string_literal: true

class InsightsSchema < RubyLLM::Schema
  array :insights do
    object do
      string :title, description: "Short, memorable name for the insight (3-5 words)"
      string :body, description: "200-300 character insight or observation"
      string :snippet, description: "Relevant text snippet from the source article"

      array :queries, description: "Research questions to explore further",
                      min_items: 2,
                      max_items: 4 do
        string max_length: 100, description: "Research question to explore further"
      end
    end
  end
end
