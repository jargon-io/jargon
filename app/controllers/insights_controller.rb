# frozen_string_literal: true

class InsightsController < ApplicationController
  def show
    @insight = Insight.by_slug!(params[:id])

    return redirect_to @insight.cluster, status: :moved_permanently if @insight.clustered?

    @more_from_article = @insight.article.insights.complete.where.not(id: @insight.id)

    exclude_items = [@insight, @insight.article] + @more_from_article.to_a

    @similar_items = SimilarItemsQuery.new(
      embedding: @insight.embedding,
      limit: 8,
      exclude: exclude_items
    ).call

    @topics_with_items = @insight.topics.filter_map do |topic|
      items = TopicExplorationQuery.new(
        embedding: topic.embedding,
        limit: 5,
        exclude: exclude_items + @similar_items
      ).call
      [topic, items] if items.any?
    end
  end
end
