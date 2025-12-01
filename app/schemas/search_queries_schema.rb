# frozen_string_literal: true

class SearchQueriesSchema < RubyLLM::Schema
  array :queries, description: "Research questions to explore further",
                  min_items: 1,
                  max_items: 2 do
    string max_length: 60, description: "Research question (~60 chars)"
  end
end
