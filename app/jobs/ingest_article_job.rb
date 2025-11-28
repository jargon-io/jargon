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

    broadcast_update(article)
  rescue StandardError => e
    article&.update!(status: :failed)
    broadcast_update(article) if article
    raise e
  end

  private

  def broadcast_update(article)
    Turbo::StreamsChannel.broadcast_replace_to(
      "articles",
      target: article,
      partial: "articles/article",
      locals: { article: }
    )
  end
end
