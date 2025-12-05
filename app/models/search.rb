# frozen_string_literal: true

class Search < ApplicationRecord
  include Sluggable
  include Embeddable
  include Linkable
  include NormalizesMarkup
  include SearchGeneratable
  include Broadcastable

  slug :query

  embeddable :summary

  search_context -> { "Query: #{query}\nSummary: #{summary}" }

  normalizes_markup :summary, :snippet

  has_neighbors :embedding
  has_neighbors :search_query_embedding

  belongs_to :source, polymorphic: true, optional: true

  has_many :search_articles, dependent: :destroy
  has_many :articles, through: :search_articles

  enum :status, { pending: 0, searching: 1, complete: 2, failed: 3 }

  scope :not_pending, -> { where.not(status: :pending) }

  validates :query, presence: true

  def all_articles_resolved?
    articles.any? && articles.pending.none?
  end

  def viable_content?
    articles.complete.any? { |a| a.insights.complete.any? }
  end

  def all_articles_failed?
    all_articles_resolved? && articles.complete.none?
  end

  def ready_to_summarize?
    all_articles_resolved? && (viable_content? || all_articles_failed?)
  end

  def generate_search_query_embedding!
    return if search_query.blank?

    embedding = LLM.embed(search_query)
    update!(search_query_embedding: embedding.vectors)
  end

  def generate_search_query_and_embedding!
    return if search_query.present?

    query = generate_search_query
    embedding = LLM.embed(query).vectors
    update!(search_query: query, search_query_embedding: embedding)
  end

  def generate_search_query
    context = build_search_context

    LLM.chat
       .with_instructions("Generate a concise search query (5-10 words) to find articles related to the research question. Return only the query, nothing else.")
       .ask(context)
       .content
  end

  def find_related_items
    search_embedding = embedding.presence || search_query_embedding
    return [] if search_embedding.blank?

    result_articles = articles.includes(:insights)
    result_insights = result_articles.flat_map(&:rolled_up_insights)
    exclude = [source] + result_articles.to_a + result_insights.to_a

    SimilarItemsQuery.new(embedding: search_embedding, limit: 6, exclude: exclude.compact).call
  end

  private

  def build_search_context
    parts = ["Research question: #{query}"]

    case source
    when Article
      parts << "Article: #{source.title}"
      parts << "Summary: #{source.summary}"
    when Insight
      parts << "Article: #{source.article&.title}"
      parts << "Summary: #{source.article&.summary}"
      parts << "Insight: #{source.body}"
    when Search
      parts << "Previous query: #{source.query}"
      parts << "Previous summary: #{source.summary}"
    end

    parts.join("\n")
  end
end
