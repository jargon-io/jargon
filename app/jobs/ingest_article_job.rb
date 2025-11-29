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
      @article.update!(
        title: video.title,
        author: extract_speaker_from_title(video.title) || video.channel,
        published_at: video.published_at,
        text: video.transcript,
        summary: generate_summary(video.transcript),
        content_type: :video,
        status: :complete
      )
    else
      @article.update!(
        title: video&.title,
        author: video&.channel,
        published_at: video&.published_at,
        content_type: :video,
        status: :complete
      )
    end
  end

  def extract_speaker_from_title(title)
    return nil if title.blank?

    # Match patterns like "Conference: Speaker Name - Talk Title" or "Speaker Name: Talk Title"
    match = title.match(/:\s*([A-Z][a-z]+ [A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\s*[-–—]/)
    match&.[](1)
  end

  def process_web_content(url)
    text = crawl_content(url)
    evaluation = evaluate_content(text, url)
    is_paper = evaluation["is_academic_paper"]

    case evaluation["content_type"]
    when "full"
      update_article(text:, content_type: is_paper ? :paper : :full)
    when "abstract"
      handle_abstract(text, evaluation["full_text_url"], is_paper:)
    when "partial", "video", "podcast"
      update_article(text:, content_type: :partial)
      queue_embedded_video(evaluation["embedded_video_url"])
    when "paywall", "blocked"
      @article.update!(status: :failed)
    end
  end

  def handle_abstract(abstract_text, full_text_url, is_paper:)
    if full_text_url.present?
      full_text = pdf_url?(full_text_url) ? extract_pdf_text(full_text_url) : crawl_content(full_text_url)
      if full_text.present? && full_text.length > abstract_text.length * 2
        update_article(text: full_text, content_type: is_paper ? :paper : :full)
        return
      end
    end
    update_article(text: abstract_text, content_type: :partial)
  end

  def pdf_url?(url)
    url.to_s.match?(/\.pdf(\?|$)/i) || url.to_s.match?(%r{arxiv\.org/pdf/}i)
  end

  def extract_pdf_text(url)
    require "tempfile"
    require "open3"

    Tempfile.create(["article", ".pdf"]) do |file|
      response = HTTPX.plugin(:follow_redirects).get(url)
      return nil unless response.status == 200

      file.binmode
      file.write(response.body.to_s)
      file.flush

      stdout, _stderr, status = Open3.capture3("pdftotext", "-layout", file.path, "-")
      return nil unless status.success?

      stdout.strip.presence
    end
  rescue StandardError => e
    Rails.logger.warn("PDF extraction failed for #{url}: #{e.message}")
    nil
  end

  def queue_embedded_video(video_url)
    return if video_url.blank?
    return unless YoutubeClient.youtube_url?(video_url)
    return if Article.exists?(url: video_url)

    article = Article.create!(url: video_url)
    IngestArticleJob.perform_later(article.url)
  end

  CrawlResult = Struct.new(:text, :image_url, keyword_init: true)

  def crawl_content(url)
    result = crawl_with_exa(url)
    if result
      @crawl_image_url = result["image"]
      return result["text"]
    end

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
      title: presence(metadata["title"]),
      author: presence(metadata["author"]),
      published_at: parse_date(metadata["published_at"]),
      image_url: @crawl_image_url,
      text:,
      summary: generate_summary(text),
      content_type:,
      status: :complete
    )
  end

  def presence(value)
    return nil if value.blank? || value.casecmp?("null")

    value
  end

  def parse_date(date_str)
    return nil if date_str.blank? || date_str.casecmp?("null")

    Date.parse(date_str)
  rescue ArgumentError
    nil
  end

  def finalize_article
    return unless @article.complete?

    @article.generate_embedding!
    @article.cluster_if_similar!
    @article.generate_research_threads!
    broadcast_update

    GenerateInsightsJob.perform_later(@article.id)
  end

  def extract_metadata(text)
    prompt = <<~PROMPT
      Extract metadata from this article.

      URL: #{@article.url}

      Content:
      #{text.truncate(10_000)}
    PROMPT

    RubyLLM.chat
           .with_schema(ArticleMetadataSchema)
           .ask(prompt)
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
