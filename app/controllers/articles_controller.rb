# frozen_string_literal: true

class ArticlesController < ApplicationController
  def index
    @articles = Article.complete
                       .where.missing(:cluster_membership)
                       .order(created_at: :desc)

    @clusters = Cluster.for_articles.complete.order(created_at: :desc)
  end

  def show
    @article = Article.complete.find_by!(slug: params[:id])

    return redirect_to @article.cluster, status: :moved_permanently if @article.clustered?

    @similar_items = SimilarItemsQuery.new(
      embedding: @article.embedding,
      limit: 8,
      exclude: [@article] + @article.insights.to_a
    ).call
  end
end
