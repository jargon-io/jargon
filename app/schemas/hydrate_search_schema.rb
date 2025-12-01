# frozen_string_literal: true

class HydrateSearchSchema < RubyLLM::Schema
  string :summary, description: "2-4 sentence synthesis of findings that answers the user's question"
  string :snippet, description: "A key quote from one of the sources, with <strong> tags for emphasis on important phrases"
  array :followup_queries, min_items: 2, max_items: 2 do
    string max_length: 60, description: "Research question (~60 chars) for further exploration"
  end
end
