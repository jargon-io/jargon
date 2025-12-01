# frozen_string_literal: true

class AutocompleteController < ApplicationController
  def index
    return head :ok if params[:q].blank? || params[:q].length < 3

    @results = search_results(params[:q])
  end

  private

  def search_results(query)
    pattern = "%#{query}%"

    articles = Article.where("title ILIKE ?", pattern).limit(5)
    insights = Insight.where("title ILIKE ?", pattern).limit(5)

    (articles + insights)
      .sort_by { |r| r.title.downcase.index(query.downcase) || 999 }
      .first(5)
  end
end
