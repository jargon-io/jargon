# frozen_string_literal: true

class ArticleSummarySchema < RubyLLM::Schema
  string :summary, description: "200-300 character summary. Use <strong> for 1-2 key terms. State the idea directly, not what the article discusses."
end
