# frozen_string_literal: true

class SimilarItemsQuery
  THRESHOLD = 0.5

  Result = Data.define(:item, :distance)

  def initialize(embedding:, limit: 10, exclude: [])
    @embedding = embedding
    @limit = limit
    @exclude = Array(exclude)
  end

  def call
    return [] if @embedding.blank?

    results = []
    results.concat(similar_articles)
    results.concat(similar_insights)

    results
      .select { |r| r.distance < THRESHOLD }
      .sort_by(&:distance)
      .first(@limit)
      .map(&:item)
  end

  private

  def similar_articles
    scope = Article.complete.roots.includes(:children)
    scope = exclude_from_scope(scope, Article)

    scope
      .nearest_neighbors(:embedding, @embedding, distance: "cosine")
      .limit(@limit)
      .map { |a| Result.new(item: a, distance: a.neighbor_distance) }
  end

  def similar_insights
    scope = Insight.complete.roots.includes(:article)
    scope = exclude_from_scope(scope, Insight)

    scope
      .nearest_neighbors(:embedding, @embedding, distance: "cosine")
      .limit(@limit)
      .map { |i| Result.new(item: i, distance: i.neighbor_distance) }
  end

  def exclude_from_scope(scope, klass)
    excluded_ids = @exclude.select { |e| e.is_a?(klass) }.map(&:id)
    excluded_ids.any? ? scope.where.not(id: excluded_ids) : scope
  end
end
