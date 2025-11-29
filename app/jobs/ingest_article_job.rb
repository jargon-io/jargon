# frozen_string_literal: true

class IngestArticleJob < ApplicationJob
  SUMMARY_INSTRUCTIONS = <<~PROMPT
    Distill the article's key idea into a summary.

    Voice:
    - State the finding/idea directly: "People delegate unethical tasks to AI more readily..."
    - NOT commentary: "The article discusses how people..."
    - Use <strong> to emphasize 1-2 key terms or phrases
    - Preserve nuance; don't oversimplify

    Length: 200-300 characters
  PROMPT

  def perform(url)
    article = Article.find_by!(url:)

    result = crawl_with_exa(url)

    if result
      update_from_exa(article, result)
    else
      markdown = crawl_with_fallback(url)
      update_from_fallback(article, markdown)
    end

    article.generate_embedding!
    article.cluster_if_similar!

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
      text: result["text"],
      summary: generate_summary(result["text"]),
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
      summary: generate_summary(markdown),
      status: :complete
    )
  end

  def extract_metadata(markdown)
    RubyLLM.chat
           .with_schema(ArticleMetadataSchema)
           .ask("Extract the title from this article:\n\n#{markdown.truncate(10_000)}")
           .content
  end

  def generate_summary(text)
    RubyLLM.chat
           .with_instructions(SUMMARY_INSTRUCTIONS)
           .with_schema(ArticleSummarySchema)
           .ask(text.truncate(10_000))
           .content["summary"]
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
        locals: { article: }
      )
    end
  end
end
