# frozen_string_literal: true

class SearchJob < ApplicationJob
  def perform(search)
    return unless search.pending? || search.searching?

    search.update!(status: :searching)
    search.generate_search_query_and_embedding! if search.search_query.blank?

    results = ExaClient.new.search(query: search.search_query)["results"] || []
    articles = filter_results(search, results)

    articles.each do |data|
      url = data["url"]
      next if url.blank?

      article = Article.find_or_create_by!(url:) do |a|
        a.title = data["title"]
        a.origin = :discovered
      end

      search.search_articles.find_or_create_by!(article:)
    end

    SummarizeSearchJob.perform_later(search) if search.ready_to_summarize?
  rescue StandardError => e
    Rails.logger.error("SearchJob failed: #{e.message}")
    raise e
  end

  private

  def filter_results(search, results)
    return [] if results.empty?

    candidates = results.take(10).map do |r|
      { url: r["url"], title: r["title"] }
    end

    prompt = <<~PROMPT
      Research question: #{search.search_query}

      Context: #{format_source_for_prompt(search.source)}

      Candidate articles:
      #{candidates.map { |c| "- #{c[:title]} (#{c[:url]})" }.join("\n")}

      Select 1-3 articles that best answer the question. Prefer diversity. Exclude PDFs and non-article pages.
    PROMPT

    LLM.chat
       .with_schema(SelectedArticlesSchema)
       .ask(prompt)
       .content["articles"] || []
  end

  def format_source_for_prompt(source)
    case source
    when Article
      "#{source.title}: #{source.summary}"
    when Insight
      "#{source.title}: #{source.body}"
    when Search
      "#{source.search_query}: #{source.summary}"
    end
  end
end
