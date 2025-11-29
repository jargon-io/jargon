# frozen_string_literal: true

class ArticlesController < ApplicationController
  def index
    @articles = Article.complete.order(created_at: :desc)
    @article = Article.new
  end

  def show
    @article = Article.complete.find_by!(nanoid: params[:id])

    @similar_items = SimilarItemsQuery.new(
      embedding: @article.embedding,
      limit: 8,
      exclude: [@article] + @article.insights.to_a
    ).call
  end

  def create
    existing = Article.find_by(url: article_params[:url])

    if existing
      redirect_to existing
      return
    end

    @article = Article.new(article_params)

    if @article.save
      IngestArticleJob.perform_later(@article.url)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to root_path }
      end
    else
      render :index, status: :unprocessable_content
    end
  end

  private

  def article_params
    params.expect(article: [:url])
  end
end
