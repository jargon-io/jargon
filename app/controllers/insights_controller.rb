# frozen_string_literal: true

class InsightsController < ApplicationController
  def show
    @insight = Insight.by_slug!(params[:id])

    return redirect_to @insight.parent, status: :moved_permanently if @insight.child?

    if @insight.parent?
      @source_articles = @insight.children
                                 .includes(:article)
                                 .filter_map { |i| i.article&.parent || i.article }
                                 .uniq

      exclude_items = [@insight] + @source_articles + @insight.sibling_insights
    else
      exclude_items = [@insight, @insight.article].compact + @insight.sibling_insights
    end

    @similar_items = SimilarItemsQuery.new(
      embedding: @insight.embedding,
      limit: 8,
      exclude: exclude_items
    ).call
  end
end
