# frozen_string_literal: true

class ArticlesController < ApplicationController
  def show
    @article = Article.find_by!(slug: params[:id])

    return redirect_to @article.parent, status: :moved_permanently if @article.child?

    @similar_items =
      if @article.complete?
        SimilarItemsQuery.new(
          embedding: @article.embedding,
          limit: 8,
          exclude: [@article] + @article.insights.to_a
        ).call
      else
        []
      end
  end
end
