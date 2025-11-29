# frozen_string_literal: true

class ArticleMetadataSchema < RubyLLM::Schema
  string :title, description: "The article's title"
  string :author, description: "Author name(s), if present"
  string :published_at, description: "Publication date in YYYY-MM-DD format, if present"
end
