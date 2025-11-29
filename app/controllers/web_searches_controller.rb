# frozen_string_literal: true

class WebSearchesController < ApplicationController
  def create
    query = params[:q].to_s.strip
    return head :bad_request if query.blank?

    @web_search = WebSearch.create!(query:)
    WebSearchJob.perform_later(@web_search.id)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to search_path(q: query) }
    end
  end
end
