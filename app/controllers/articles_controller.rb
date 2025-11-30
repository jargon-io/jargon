# frozen_string_literal: true

class ArticlesController < ApplicationController
  def show
    @article = Article.complete.find_by!(slug: params[:id])

    return redirect_to @article.cluster, status: :moved_permanently if @article.clustered?

    exclude_items = [@article] + @article.insights.to_a

    @similar_items = SimilarItemsQuery.new(
      embedding: @article.embedding,
      limit: 8,
      exclude: exclude_items
    ).call
  end
end
