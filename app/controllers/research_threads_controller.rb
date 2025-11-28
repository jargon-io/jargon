# frozen_string_literal: true

class ResearchThreadsController < ApplicationController
  def show
    @thread = ResearchThread.find_by!(nanoid: params[:id])
    @source_article = @thread.source_article
    @thread_articles = @thread.thread_articles.includes(:article)
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
end
