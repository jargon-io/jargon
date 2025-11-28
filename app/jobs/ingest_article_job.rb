# frozen_string_literal: true

class IngestArticleJob < ApplicationJob
  def perform(url)
    article = Article.find_or_initialize_by(url:)
    article.text = ExaClient.new.crawl(url:)
    article.save!
  end
end
