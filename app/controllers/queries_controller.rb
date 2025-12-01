# frozen_string_literal: true

class QueriesController < ApplicationController
  def create
    query = params[:q].to_s.strip

    return redirect_to root_path if query.blank?

    if url?(query)
      redirect_to Article.find_or_create_by!(url: query)
    else
      redirect_to find_or_create_search(query)
    end
  end

  private

  def url?(input)
    input.match?(%r{\Ahttps?://}i)
  end

  def find_or_create_search(query)
    if (pending = find_pending_search(query))
      pending.generate_search_query_and_embedding!
      pending.update!(status: :searching)
      SearchJob.perform_later(pending)
      return pending
    end

    search = Search.create!(
      query:,
      source: find_source,
      status: :searching
    )
    search.generate_search_query_and_embedding!
    SearchJob.perform_later(search)

    search
  end

  def find_pending_search(query)
    source = find_source
    return nil unless source

    Search.pending.find_by(query:, source:)
  end

  def find_source
    return nil unless params[:source_type].in?(%w[Article Insight Search])

    params[:source_type].constantize.find_by(id: params[:source_id])
  end
end
