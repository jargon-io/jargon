# frozen_string_literal: true

class IngestArticleJob < ApplicationJob
  def perform(url)
    article = Article.find_by!(url:)

    result = crawl_with_exa(url)

    if result
      update_from_exa(article, result)
    else
      markdown = crawl_with_fallback(url)
      update_from_fallback(article, markdown)
    end

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

  def crawl_with_exa(url)
    response = ExaClient.new.crawl(urls: [url])
    return nil if response["results"].empty?

    response["results"].first
  end

  def crawl_with_fallback(url)
    Crawl4aiClient.new.crawl(url)
  end

  def update_from_exa(article, result)
    article.update!(
      title: result["title"],
      text: result["text"], summary: result["summary"],
      author: result["author"],
      image_url: result["image"],
      published_at: result["publishedDate"],
      status: :complete
    )
  end

  def update_from_fallback(article, markdown)
    metadata = extract_metadata(markdown)

    article.update!(
      title: metadata["title"],
      text: markdown,
      summary: metadata["summary"],
      status: :complete
    )
  end

  def extract_metadata(markdown)
    RubyLLM.chat
           .with_schema(ArticleMetadataSchema)
           .ask("Extract the title and write a 200-300 character summary:\n\n#{markdown.truncate(10_000)}")
           .content
  end

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
        target: article,
        partial: "articles/article",
        locals: { article:, relevance_note: ta.relevance_note }
      )
    end
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
