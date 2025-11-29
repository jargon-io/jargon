# frozen_string_literal: true

class TopicExplorationQuery
  THRESHOLD = 0.5

  Result = Data.define(:item, :distance)

  def initialize(embedding:, limit: 5, exclude: [])
    @embedding = embedding
    @limit = limit
    @exclude = Array(exclude)
  end

  def call
    return [] if @embedding.blank?

    results = []
    results.concat(explore_articles)
    results.concat(explore_insights)
    results.concat(explore_clusters)

    results
      .select { |r| r.distance < THRESHOLD }
      .sort_by(&:distance)
      .first(@limit)
      .map(&:item)
  end

  private

  def explore_articles
    scope = Article.complete.where.missing(:cluster_membership)
    scope = exclude_from_scope(scope, Article)
    query_scope(scope)
  end

  def explore_insights
    scope = Insight.complete.where.missing(:cluster_membership)
    scope = exclude_from_scope(scope, Insight)
    query_scope(scope)
  end

  def explore_clusters
    scope = Cluster.complete
    scope = exclude_from_scope(scope, Cluster)
    query_scope(scope)
  end

  def query_scope(scope)
    scope
      .nearest_neighbors(:embedding, @embedding, distance: "cosine")
      .limit(@limit)
      .map { |r| Result.new(item: r, distance: r.neighbor_distance) }
  end

  def exclude_from_scope(scope, klass)
    excluded_ids = @exclude.select { |e| e.is_a?(klass) }.map(&:id)
    excluded_ids.any? ? scope.where.not(id: excluded_ids) : scope
  end
end
