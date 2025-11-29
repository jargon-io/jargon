# frozen_string_literal: true

class SearchController < ApplicationController
  def show
    @query = params[:q].to_s.strip
    return redirect_to articles_path if @query.blank?

    if url?(@query)
      create_article_from_url(@query)
      redirect_to articles_path
    else
      @results = search_library(@query)
    end
  end

  private

  def url?(input)
    input.match?(%r{\Ahttps?://}i)
  end

  def create_article_from_url(url)
    return if Article.exists?(url:)

    Article.create!(url:).tap do |article|
      article.broadcast_prepend_to("articles", target: "articles")
      IngestArticleJob.perform_later(article.url)
    end
  end

  def search_library(query)
    embedding = RubyLLM.embed(
      query,
      model: Embeddable::MODEL,
      provider: :openrouter,
      assume_model_exists: true
    ).vectors

    SimilarItemsQuery.new(embedding:, limit: 20).call
  end
end
