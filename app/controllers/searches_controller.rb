# frozen_string_literal: true

class SearchesController < ApplicationController
  def show
    @search = Search.by_slug!(params[:id])
    @result_articles = @search.articles.includes(:insights)
    @result_insights = @result_articles.flat_map(&:rolled_up_insights).uniq.first(6)
    @related_items = find_related_items
  end

  def update
    @search = Search.by_slug!(params[:id])
    start_search!
    redirect_to @search
  end

  private

  def start_search!
    return unless @search.pending?

    @search.generate_search_query_and_embedding!
    @search.update!(status: :searching)
    SearchJob.perform_later(@search)
  end

  def find_related_items
    embedding = @search.embedding.presence || @search.search_query_embedding

    return [] if embedding.blank?

    exclude = [@search.source] + @result_articles.to_a + @result_insights.to_a

    SimilarItemsQuery.new(embedding:, limit: 6, exclude:).call
  end
end
