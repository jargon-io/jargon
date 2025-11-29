# frozen_string_literal: true

class ClustersController < ApplicationController
  def show
    @cluster = Cluster.by_slug!(params[:id])
    @members = @cluster.members

    @source_items = compute_source_items
    @insights = compute_insights

    @similar_items = SimilarItemsQuery.new(
      embedding: @cluster.embedding,
      limit: 8,
      exclude: [@cluster] + @members + @source_items + @insights
    ).call
  end

  private

  def compute_source_items
    return [] unless @cluster.clusterable_type == "Insight"

    Article.where(id: @members.map(&:article_id))
           .includes(:cluster)
           .map { |a| a.cluster || a }
           .uniq
  end

  def compute_insights
    return [] unless @cluster.clusterable_type == "Article"

    Insight.complete
           .where(article_id: @members.map(&:id))
           .includes(:cluster)
           .map { |i| i.cluster || i }
           .uniq
  end
end
