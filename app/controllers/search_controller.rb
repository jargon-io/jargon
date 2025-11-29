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
    article = Article.find_by(url:)
    return article if article

    Article.create!(url:).tap { IngestArticleJob.perform_later(it.url) }
  end

  def search_library(query)
    embedding = EmbeddingService.generate(query)
    return [] if embedding.nil?

    SimilarItemsQuery.new(embedding:, limit: 20).call
  end
end
