# frozen_string_literal: true

class ArticleMetadataSchema < RubyLLM::Schema
  string :title, description: "The article's title"
  string :summary, description: "200-300 character summary of the article's main idea"
end
