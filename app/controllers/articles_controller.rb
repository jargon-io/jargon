# frozen_string_literal: true

class ArticlesController < ApplicationController
  def show
    @article = Article.resolve_identifier!(params[:id])

    return redirect_to @article.parent, status: :moved_permanently if @article.child?

    redirect_to @article, status: :moved_permanently if @article.slug.present? && @article.slug != params[:id]
  end
end
