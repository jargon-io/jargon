# frozen_string_literal: true

class Search < ApplicationRecord
  include Sluggable
  include Embeddable
  include Linkable
  include NormalizesMarkup
  include SearchGeneratable

  slug :query

  embeddable :summary

  search_context -> { "Query: #{query}\nSummary: #{summary}" }

  normalizes_markup :summary, :snippet

  has_neighbors :embedding
  has_neighbors :search_query_embedding

  belongs_to :source, polymorphic: true, optional: true

  has_many :search_articles, dependent: :destroy
  has_many :articles, through: :search_articles

  enum :status, { pending: 0, searching: 1, complete: 2 }

  scope :not_pending, -> { where.not(status: :pending) }

  validates :query, presence: true

  def pending_articles_count
    articles.pending.count
  end

  def all_articles_ready?
    articles.any? && pending_articles_count.zero?
  end

  def all_insights_ready?
    return false unless all_articles_ready?

    articles.all? { |a| a.insights.complete.any? }
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
