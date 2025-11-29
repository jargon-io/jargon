# frozen_string_literal: true

class ResearchThreadsController < ApplicationController
  def show
    @thread = ResearchThread.find_by!(nanoid: params[:id])
    @source_article = @thread.source_article
    @thread_articles = @thread.thread_articles.includes(:article)

    @related_items = find_related_items
  end

  def create
    @thread = find_or_create_thread
    ResearchThreadJob.perform_later(@thread.id) if @thread.pending?
    redirect_to @thread
  end

  private

  def find_or_create_thread
    if params[:research_thread_id].present?
      # Clicking existing thread from insight page
      ResearchThread.find(params[:research_thread_id])
    elsif params[:insight_id].present? && params[:query].present?
      # Custom query from insight page
      insight = Insight.find(params[:insight_id])
      insight.research_threads.create!(
        query: params[:query],
        article: insight.article
      )
    else
      raise ActionController::BadRequest, "Missing required parameters"
    end
  end

  def find_related_items
    return [] unless @thread.insight&.embedding.present?

    discovered_article_ids = @thread_articles.map(&:article_id)

    SimilarItemsQuery.new(
      embedding: @thread.insight.embedding,
      limit: 6,
      exclude: [@thread.insight, @source_article].compact
    ).call.reject { |item| item.is_a?(Article) && discovered_article_ids.include?(item.id) }
  end
end
