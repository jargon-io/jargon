# frozen_string_literal: true

class WelcomeController < ApplicationController
  def index
    @items = recent_items(25)
  end

  private

  def recent_items(limit)
    articles = Article.where(status: %i[pending complete])
                      .where.missing(:cluster_membership)
                      .order(created_at: :desc)
                      .limit(limit)

    article_clusters = Cluster.for_articles.complete.order(created_at: :desc).limit(limit)

    insights = Insight.complete
                      .where.missing(:cluster_membership)
                      .order(created_at: :desc)
                      .limit(limit)

    insight_clusters = Cluster.for_insights.complete.order(created_at: :desc).limit(limit)

    (articles + article_clusters + insights + insight_clusters)
      .sort_by(&:created_at)
      .reverse
      .first(limit)
  end
end
