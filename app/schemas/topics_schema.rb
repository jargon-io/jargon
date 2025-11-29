# frozen_string_literal: true

class TopicsSchema < RubyLLM::Schema
  array :topics, description: "3-5 exploratory topic phrases", min_items: 3, max_items: 5 do
    string max_length: 50
  end
end
