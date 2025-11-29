# frozen_string_literal: true

class WebSearchJob < ApplicationJob
  def perform(web_search_id)
    web_search = WebSearch.find(web_search_id)

    results = ExaClient.new.search(query: web_search.query)
    urls = results["results"].pluck("url").first(5)

    urls.each do |url|
      article = Article.find_or_create_by!(url:)
      web_search.web_search_articles.find_or_create_by!(article:)

      IngestArticleJob.perform_later(url) if article.pending?

      broadcast_article(web_search, article)
    end

    web_search.update!(status: :complete)
    broadcast_complete(web_search)
  end

  private

  def broadcast_article(web_search, article)
    Turbo::StreamsChannel.broadcast_remove_to(
      "web_search_#{web_search.id}",
      target: "web_search_loading"
    )

    Turbo::StreamsChannel.broadcast_append_to(
      "web_search_#{web_search.id}",
      target: "from-the-web",
      partial: "articles/article",
      locals: { article: }
    )
  end

  def broadcast_complete(web_search)
    Turbo::StreamsChannel.broadcast_remove_to(
      "web_search_#{web_search.id}",
      target: "web_search_loading"
    )
  end
end
