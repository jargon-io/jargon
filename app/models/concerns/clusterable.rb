# frozen_string_literal: true

module Clusterable
  extend ActiveSupport::Concern

  THRESHOLDS = {
    "Article" => 0.15,  # Looser - syndicated content varies slightly
    "Insight" => 0.20   # Topical similarity
  }.freeze

  TITLE_SIMILARITY_THRESHOLD = 0.8

  included do
    has_one :cluster_membership, as: :clusterable, dependent: :destroy
    has_one :cluster, through: :cluster_membership
  end

  def clustered?
    cluster_membership.present?
  end

  def cluster_siblings
    return [] unless cluster

    cluster.members.reject { |m| m == self }
  end

  def cluster_if_similar!
    return if embedding.blank?
    return if clustered?

    threshold = THRESHOLDS.fetch(self.class.name)
    match = find_cluster_match(threshold) || find_unclustered_match(threshold)

    case match
    when Cluster
      add_to_cluster(match)
    when Article, Insight
      create_cluster_with(match)
    end
  end

  private

  def find_cluster_match(threshold)
    Cluster.complete
           .where(clusterable_type: self.class.name)
           .nearest_neighbors(:embedding, embedding, distance: "cosine")
           .first
           &.then { |c| similar_enough?(c, threshold) ? c : nil }
  end

  def find_unclustered_match(threshold)
    scope = self.class
                .where.not(id:)
                .where.missing(:cluster_membership)
                .where.not(embedding: nil)

    # Don't cluster insights from the same article
    scope = scope.where.not(article_id:) if is_a?(Insight)

    scope.nearest_neighbors(:embedding, embedding, distance: "cosine")
         .first
         &.then { |i| similar_enough?(i, threshold) ? i : nil }
  end

  def similar_enough?(match, threshold)
    return false unless match

    if is_a?(Article)
      other_title = match.is_a?(Cluster) ? match.name : match.title
      title_similarity(title, other_title) >= TITLE_SIMILARITY_THRESHOLD
    else
      match.neighbor_distance < threshold
    end
  end

  def title_similarity(a, b)
    return 0.0 if a.blank? || b.blank?

    a_normalized = a.downcase.gsub(/[^\w\s]/, "")
    b_normalized = b.downcase.gsub(/[^\w\s]/, "")

    return 1.0 if a_normalized == b_normalized

    longer = [a_normalized.length, b_normalized.length].max.to_f
    return 0.0 if longer.zero?

    distance = levenshtein_distance(a_normalized, b_normalized)
    1.0 - (distance / longer)
  end

  def levenshtein_distance(s, t)
    m = s.length
    n = t.length

    return n if m.zero?
    return m if n.zero?

    d = Array.new(m + 1) { |i| i }
    x = nil

    (1..n).each do |j|
      x = Array.new(m + 1)
      x[0] = j

      (1..m).each do |i|
        cost = s[i - 1] == t[j - 1] ? 0 : 1
        x[i] = [x[i - 1] + 1, d[i] + 1, d[i - 1] + cost].min
      end

      d = x
    end

    x[m]
  end

  def add_to_cluster(cluster)
    cluster.cluster_memberships.create!(clusterable: self)
    cluster.regenerate_metadata! if cluster.member_count > 2
  end

  def create_cluster_with(other)
    cluster = Cluster.create!(
      clusterable_type: self.class.name,
      status: :pending
    )

    cluster.cluster_memberships.create!(clusterable: other)
    cluster.cluster_memberships.create!(clusterable: self)

    cluster.generate_metadata!
  end
end
