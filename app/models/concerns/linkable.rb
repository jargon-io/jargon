# frozen_string_literal: true

module Linkable
  extend ActiveSupport::Concern

  # Returns insights that can be linked to from this record's content
  def linkable_insights(limit: 10)
    return Insight.none if embedding.blank?

    Insight.complete
           .where.missing(:cluster_membership)
           .where.not(id: excluded_insight_ids)
           .nearest_neighbors(:embedding, embedding, distance: "cosine")
           .limit(limit)
  end

  # Formatted list for LLM prompt
  def linkable_insights_prompt(limit: 10)
    linkable_insights(limit:).map { |i| "- [insight:#{i.slug}] #{i.title}" }.join("\n")
  end

  # Set of valid link keys for validation
  def valid_link_keys(limit: 10)
    linkable_insights(limit:).to_set(&:slug_with_class)
  end

  private

  def excluded_insight_ids
    case self
    when Insight
      [id] + article.insight_ids
    when Article
      insight_ids
    when Cluster
      members.select { |m| m.is_a?(Insight) }.map(&:id)
    else
      []
    end
  end
end
