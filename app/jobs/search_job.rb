# frozen_string_literal: true

class SearchJob < ApplicationJob
  def perform(search)
    search.update!(status: :searching) unless search.searching?

    if search.search_query.blank?
      query = generate_search_query(search)
      search.update!(search_query: query)
      search.generate_search_query_embedding!
    end

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

      broadcast_article(search, article)
    end

    HydrateSearchJob.perform_later(search) if search.all_insights_ready?
  rescue StandardError => e
    Rails.logger.error("SearchJob failed: #{e.message}")
    raise e
  end

  private

  def generate_search_query(search)
    context = build_context(search)

    LLM.chat
       .with_instructions("Generate a concise search query (5-10 words) to find articles related to the research question. Return only the query, nothing else.")
       .ask(context)
       .content
  end

  def build_context(search)
    parts = ["Research question: #{search.query}"]

    case search.source
    when Article
      parts << "Article: #{search.source.title}"
      parts << "Summary: #{search.source.summary}"
    when Insight
      parts << "Article: #{search.source.article&.title}"
      parts << "Summary: #{search.source.article&.summary}"
      parts << "Insight: #{search.source.body}"
    when Search
      parts << "Previous query: #{search.source.query}"
      parts << "Previous summary: #{search.source.summary}"
    end

    parts.join("\n")
  end

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

  def broadcast_article(search, article)
    Turbo::StreamsChannel.broadcast_remove_to(
      "search_#{search.id}",
      target: "results_loading"
    )

    Turbo::StreamsChannel.broadcast_append_to(
      "search_#{search.id}",
      target: "search_results",
      partial: "articles/article",
      locals: { article: }
    )
  end
end
