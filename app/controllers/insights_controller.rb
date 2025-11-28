# frozen_string_literal: true

class InsightsController < ApplicationController
  def show
    @insight = Insight.find_by!(nanoid: params[:id])
    @article = @insight.article

    @similar_insights =
      if @insight.embedding.present?
        @insight.nearest_neighbors(:embedding, distance: "cosine").complete.limit(5)
      else
        []
      end
  end
end
