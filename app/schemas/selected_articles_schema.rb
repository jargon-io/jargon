# frozen_string_literal: true

class SelectedArticlesSchema < RubyLLM::Schema
  array :articles do
    object do
      string :title, description: "Title of the selected article"
      string :url, description: "URL of the selected article"
      string :relevance_note, description: "Brief explanation of why this article is relevant to the research question"
    end
  end
end
