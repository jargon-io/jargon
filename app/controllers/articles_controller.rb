# frozen_string_literal: true

class ArticlesController < ApplicationController
  def index
    @articles = Article.where(status: %i[pending complete])
                       .where.missing(:cluster_membership)
                       .order(created_at: :desc)

    @clusters = Cluster.for_articles.complete.order(created_at: :desc)
  end

  def show
    @article = Article.complete.find_by!(slug: params[:id])

    return redirect_to @article.cluster, status: :moved_permanently if @article.clustered?

    exclude_items = [@article] + @article.insights.to_a

    @similar_items = SimilarItemsQuery.new(
      embedding: @article.embedding,
      limit: 8,
      exclude: exclude_items
    ).call

    @topics_with_items = @article.topics.filter_map do |topic|
      items = TopicExplorationQuery.new(
        embedding: topic.embedding,
        limit: 5,
        exclude: exclude_items + @similar_items
      ).call
      [topic, items] if items.any?
    end
  end
end
