# frozen_string_literal: true

class BackfillClustersJob < ApplicationJob
  def perform(reset: false)
    reset_clusters if reset
    backfill_articles
    backfill_insights
  end

  private

  def reset_clusters
    Cluster.destroy_all
  end

  def backfill_articles
    Article.complete
           .where.not(embedding: nil)
           .where.missing(:cluster_membership)
           .find_each(&:cluster_if_similar!)
  end

  def backfill_insights
    Insight.complete
           .where.not(embedding: nil)
           .where.missing(:cluster_membership)
           .find_each(&:cluster_if_similar!)
  end
end
