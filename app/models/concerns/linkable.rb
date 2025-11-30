# frozen_string_literal: true

module Linkable
  extend ActiveSupport::Concern

  def linkable_insights(limit: 20)
    return Insight.none if embedding.blank?

    insights = Insight.complete
                      .roots
                      .nearest_neighbors(:embedding, embedding, distance: "cosine")
                      .limit(limit)

    insights = insights.where.not(id:) if is_a?(Insight)

    insights
  end
end
