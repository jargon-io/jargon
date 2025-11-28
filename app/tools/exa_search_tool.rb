# frozen_string_literal: true

class ExaSearchTool < RubyLLM::Tool
  description "Search for articles on the web related to a research question"

  param :query, desc: "Search query to find relevant articles"
  param :num_results, type: :integer, desc: "Number of results to return (1-10)", required: false

  def initialize(exa_client: ExaClient.new)
    @exa_client = exa_client
  end

  def execute(query:, num_results: 10)
    results = @exa_client.search(query:)
    results["results"].take(num_results).map do |r|
      {
        url: r["url"],
        title: r["title"],
        snippet: r["text"]&.truncate(300)
      }
    end
  rescue StandardError => e
    { error: e.message }
  end
end
