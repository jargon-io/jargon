# frozen_string_literal: true

class SearchesController < ApplicationController
  def show
    @search = Search.resolve_identifier!(params[:id])

    redirect_to @search, status: :moved_permanently if @search.slug.present? && @search.slug != params[:id]
  end

  def update
    @search = Search.resolve_identifier!(params[:id])
    start_search!
    redirect_to @search
  end

  private

  def start_search!
    return unless @search.pending?

    SearchJob.perform_later(@search)
  end
end
