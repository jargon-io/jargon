# frozen_string_literal: true

class ResearchQueriesSchema < RubyLLM::Schema
  array :queries, description: "Research questions to explore further",
                  min_items: 1,
                  max_items: 5 do
    string max_length: 100, description: "Research question to explore further"
  end
end
