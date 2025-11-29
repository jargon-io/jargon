# frozen_string_literal: true

class IngestArticleJob < ApplicationJob
  SUMMARY_INSTRUCTIONS = <<~PROMPT
    Distill the article's key idea into a summary.

    Voice:
    - State the finding/idea directly: "People delegate unethical tasks to AI more readily..."
    - NOT commentary: "The article discusses how people..."
    - Use <strong> HTML tags to emphasize 1-2 key terms (NOT markdown **bold**)
    - Preserve nuance; don't oversimplify

    Length: 200-300 characters
  PROMPT

  CONTENT_EVALUATION_INSTRUCTIONS = <<~PROMPT
    Evaluate this scraped web content and classify it.

    Classifications:
    - full: Complete article with substantial content
    - partial: Some content but incomplete (timestamps only, table of contents, excerpt)
    - abstract: Academic abstract or summary with a link to full text
    - video: YouTube or video page without transcript
    - podcast: Podcast episode page without transcript
    - paywall: Content behind paywall or login
    - blocked: Captcha, access denied, or error page

    If this is an abstract, look for a "full text", "PDF", or "DOI" link.
  PROMPT

  def perform(url)
    @article = Article.find_by!(url:)

    if YoutubeClient.youtube_url?(url)
      process_youtube(url)
    else
      process_web_content(url)
    end

    finalize_article
  rescue StandardError => e
    Rails.logger.error("IngestArticleJob failed: #{e.message}")
    @article&.update!(status: :failed)
    broadcast_update
    raise e
  end

  private

  def process_youtube(url)
    video = YoutubeClient.new.fetch(url)

    if video&.transcript.present?
      update_article(text: video.transcript, content_type: :video)
      @article.update!(title: video.title) if video.title.present?
    else
      @article.update!(
        title: video&.title,
        content_type: :video,
        status: :complete,
        summary:
      )
    end
  end

  def process_web_content(url)
    text = crawl_content(url)
    evaluation = evaluate_content(text, url)

    case evaluation["content_type"]
    when "full"
      update_article(text:, content_type: :full)
    when "abstract"
      handle_abstract(text, evaluation["full_text_url"])
    when "partial", "video", "podcast"
      update_article(text:, content_type: :partial)
      queue_embedded_video(evaluation["embedded_video_url"])
    when "paywall", "blocked"
      @article.update!(status: :failed)
    end
  end

  def handle_abstract(abstract_text, full_text_url)
    if full_text_url.present?
      full_text = crawl_content(full_text_url)
      if full_text.length > abstract_text.length * 2
        update_article(text: full_text, content_type: :full)
        return
      end
    end
    update_article(text: abstract_text, content_type: :partial)
  end

  def queue_embedded_video(video_url)
    return if video_url.blank?
    return unless YoutubeClient.youtube_url?(video_url)
    return if Article.exists?(url: video_url)

    article = Article.create!(url: video_url)
    IngestArticleJob.perform_later(article.url)
  end

  def crawl_content(url)
    result = crawl_with_exa(url)
    return result["text"] if result

    crawl_with_fallback(url)
  end

  def crawl_with_exa(url)
    response = ExaClient.new.crawl(urls: [url])
    return nil if response["results"].empty?

    result = response["results"].first
    return nil if result["text"].to_s.length < 500

    result
  end

  def crawl_with_fallback(url)
    Crawl4aiClient.new.crawl(url)
  end

  def evaluate_content(text, url)
    prompt = "URL: #{url}\n\nContent:\n#{text.truncate(5000)}"

    RubyLLM.chat
           .with_instructions(CONTENT_EVALUATION_INSTRUCTIONS)
           .with_schema(ContentEvaluationSchema)
           .ask(prompt)
           .content
  end

  def update_article(text:, content_type:)
    metadata = extract_metadata(text)

    @article.update!(
      title: metadata["title"],
      text:,
      summary: generate_summary(text),
      content_type:,
      status: :complete
    )
  end

  def finalize_article
    return unless @article.complete?

    @article.generate_embedding!
    @article.cluster_if_similar!
    broadcast_update

    GenerateInsightsJob.perform_later(@article.id) unless @article.partial?
  end

  def extract_metadata(text)
    RubyLLM.chat
           .with_schema(ArticleMetadataSchema)
           .ask("Extract the title from this article:\n\n#{text.truncate(10_000)}")
           .content
  end

  def generate_summary(text)
    RubyLLM.chat
           .with_instructions(SUMMARY_INSTRUCTIONS)
           .with_schema(ArticleSummarySchema)
           .ask(text.truncate(10_000))
           .content["summary"]
  end

  def broadcast_update
    Turbo::StreamsChannel.broadcast_replace_to(
      "articles",
      target: @article,
      partial: "articles/article",
      locals: { article: @article }
    )

    @article.thread_articles.includes(:research_thread).find_each do |ta|
      Turbo::StreamsChannel.broadcast_replace_to(
        "research_thread_#{ta.research_thread_id}",
        target: @article,
        partial: "articles/article",
        locals: { article: @article }
      )
    end
  end
end
