# frozen_string_literal: true

class InsightsController < ApplicationController
  def show
    @insight = Insight.by_slug!(params[:id])

    return redirect_to @insight.cluster, status: :moved_permanently if @insight.clustered?

    @more_from_article = @insight.article.insights.complete.where.not(id: @insight.id)

    exclude_items = [@insight, @insight.article] + @more_from_article.to_a

    @similar_items = SimilarItemsQuery.new(
      embedding: @insight.embedding,
      limit: 8,
      exclude: exclude_items
    ).call
  end
end
