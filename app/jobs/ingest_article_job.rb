# frozen_string_literal: true

class IngestArticleJob < ApplicationJob
  def perform(url)
    article = Article.find_by!(url:)
    response = ExaClient.new.crawl(urls: [url])
    result = response["results"].first

    article.update!(
      title: result["title"],
      text: result["text"],
      summary: result["summary"],
      author: result["author"],
      image_url: result["image"],
      published_at: result["publishedDate"],
      status: :complete
    )

    Turbo::StreamsChannel.broadcast_prepend_to(
      "articles",
      target: "articles",
      partial: "articles/article",
      locals: { article: }
    )
  end
end
