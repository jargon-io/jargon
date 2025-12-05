# frozen_string_literal: true

class SummarizeSearchJob < ApplicationJob
  INSTRUCTIONS = <<~PROMPT
    Synthesize the search results into a coherent response to the user's question.

    Generate:
    - summary: A 2-4 sentence synthesis that directly answers the question
    - snippet: A key quote from one of the articles or insights, using <strong> tags to emphasize important phrases
    - followup_queries: 2 questions to explore further (~60 chars each). Questions should help develop wholistic, intuitive, first-principles, or nuanced understanding, or connect to new domains with useful insights. Don't just drill down into specifics.
  PROMPT

  def perform(search)
    return if search.complete? || search.failed?

    if search.all_articles_failed?
      search.update!(status: :failed)
      return
    end

    content = aggregate_content(search)
    result = generate_summary(content)

    search.update!(
      summary: result["summary"],
      snippet: result["snippet"],
      status: :complete
    )

    search.generate_embedding!

    create_followup_searches(search, result["followup_queries"])

    AddLinksJob.perform_now(search)
  end

  private

  def aggregate_content(search)
    parts = [
      "User's question: #{search.query}",
      "Optimized search query: #{search.search_query}"
    ]

    search.articles.complete.each do |article|
      parts << "---"
      parts << "Article: #{article.title}"
      parts << "Summary: #{article.summary}"

      article.rolled_up_insights.limit(5).each do |insight|
        parts << "- Insight: #{insight.title}: #{insight.body}"
      end
    end

    if search.search_query_embedding.present?
      related = SimilarItemsQuery.new(
        embedding: search.search_query_embedding,
        limit: 5,
        exclude: search.articles.to_a
      ).call

      if related.any?
        parts << "---"
        parts << "Related from library:"
        related.each do |item|
          case item
          when Article
            parts << "- Article: #{item.title}: #{item.summary}"
          when Insight
            parts << "- Insight: #{item.title}: #{item.body}"
          end
        end
      end
    end

    parts.join("\n")
  end

  def generate_summary(content)
    LLM.chat
       .with_instructions(INSTRUCTIONS)
       .with_schema(SummarizeSearchSchema)
       .ask(content)
       .content
  end

  def create_followup_searches(search, queries)
    return if queries.blank?

    queries.each do |query|
      search.searches.create!(query:, source: search.source)
    end
  end
end
