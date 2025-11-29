# frozen_string_literal: true

class ArticlesController < ApplicationController
  def index
    @articles = Article.complete.order(created_at: :desc)
  end

  def show
    @article = Article.complete.find_by!(nanoid: params[:id])

    @similar_items = SimilarItemsQuery.new(
      embedding: @article.embedding,
      limit: 8,
      exclude: [@article] + @article.insights.to_a
    ).call
  end

end
