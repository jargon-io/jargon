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

    generate_embedding(article)
    broadcast_update(article)

    GenerateInsightsJob.perform_later(article.id)
  rescue StandardError => e
    Rails.logger.error("IngestArticleJob failed: #{e.message}")
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

    article.thread_articles.includes(:research_thread).find_each do |ta|
      Turbo::StreamsChannel.broadcast_replace_to(
        "research_thread_#{ta.research_thread_id}",
        target: dom_id(article, :thread),
        partial: "research_threads/thread_article",
        locals: { article:, relevance_note: ta.relevance_note }
      )
    end
  end

  def dom_id(record, prefix = nil)
    ActionView::RecordIdentifier.dom_id(record, prefix)
  end

  def generate_embedding(article)
    return if article.summary.blank?

    embedding = RubyLLM.embed(article.summary,
                              model: "openai/text-embedding-3-small",
                              provider: :openrouter,
                              assume_model_exists: true)

    article.update!(embedding: embedding.vectors)
  end
end
