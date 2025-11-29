# frozen_string_literal: true

class ResearchThreadsController < ApplicationController
  ALLOWED_SUBJECT_TYPES = %w[Article Insight Cluster].freeze

  def show
    @thread = ResearchThread.by_slug!(params[:id])
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
      ResearchThread.find(params[:research_thread_id])
    elsif params[:subject_id].present? && params[:subject_type].present? && params[:query].present?
      subject = find_subject(params[:subject_type], params[:subject_id])
      subject.research_threads.create!(query: params[:query])
    else
      raise ActionController::BadRequest, "Missing required parameters"
    end
  end

  def find_subject(type, id)
    raise ActionController::BadRequest, "Invalid subject type" unless ALLOWED_SUBJECT_TYPES.include?(type)

    type.constantize.find(id)
  end

  def find_related_items
    return [] if @thread.subject&.embedding.blank?

    discovered_article_ids = @thread_articles.map(&:article_id)

    SimilarItemsQuery.new(
      embedding: @thread.subject.embedding,
      limit: 6,
      exclude: [@thread.subject, @source_article].compact
    ).call.reject { |item| item.is_a?(Article) && discovered_article_ids.include?(item.id) }
  end
end
