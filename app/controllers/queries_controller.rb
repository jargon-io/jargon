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
    source = find_source

    if (pending = Search.pending.find_by(query:, source:))
      return pending
    end

    Search.create!(query:, source:).tap do |search|
      SearchJob.perform_later(search)
    end
  end

  def find_source
    return nil unless params[:source_type].in?(%w[Article Insight Search])

    params[:source_type].constantize.find_by(id: params[:source_id])
  end
end
