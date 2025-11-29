# frozen_string_literal: true

class ClustersController < ApplicationController
  def show
    @cluster = Cluster.by_slug!(params[:id])
    @members = @cluster.members

    @source_items = compute_source_items

    @similar_items = SimilarItemsQuery.new(
      embedding: @cluster.embedding,
      limit: 8,
      exclude: [@cluster] + @members + @source_items
    ).call
  end

  private

  def compute_source_items
    return [] unless @cluster.clusterable_type == "Insight"

    @members.map(&:article)
            .map { |a| a.cluster || a }
            .uniq
  end
end
