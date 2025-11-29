# frozen_string_literal: true

class InsightsController < ApplicationController
  def show
    @insight = Insight.by_slug!(params[:id])
    @more_from_article = @insight.article.insights.complete.where.not(id: @insight.id)

    @similar_items = SimilarItemsQuery.new(
      embedding: @insight.embedding,
      limit: 8,
      exclude: [@insight, @insight.article] + @more_from_article
    ).call
  end
end
