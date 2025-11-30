# frozen_string_literal: true

class WelcomeController < ApplicationController
  def index
    @items = recent_items(25)
  end

  private

  def recent_items(limit)
    articles = Article.complete
                      .includes(:parent)
                      .order(created_at: :desc)
                      .limit(limit)

    insights = Insight.complete
                      .includes(:parent)
                      .order(created_at: :desc)
                      .limit(limit)

    (articles + insights)
      .map { |item| item.parent || item }
      .uniq
      .sort_by(&:created_at)
      .reverse
      .first(limit)
  end
end
