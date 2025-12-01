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

  def perform(article)
    @article = article
    @old_slug = article.slug

    if YoutubeClient.youtube_url?(article.url)
      process_youtube(article.url)
    else
      process_web_content(article.url)
    end

    finalize_article
  rescue StandardError => e
    Rails.logger.error("IngestArticleJob failed: #{e.message}")
    @article&.update!(status: :failed)
    broadcast_update
    notify_searches_of_resolution
    raise e
  end

  private

  def process_youtube(url)
    video = YoutubeClient.new.fetch(url)
    return @article.update!(status: :failed) unless video

    text = build_video_text(video)
    metadata = extract_video_metadata(video)

    @article.update!(
      title: metadata["title"].presence || video.title,
      author: metadata["author"].presence || video.channel,
      published_at: parse_date(metadata["published_at"]) || video.published_at,
      text:,
      summary: metadata["summary"],
      content_type: :video,
      status: :complete
    )
  end

  def build_video_text(video)
    parts = []
    parts << video.description if video.description.present?
    parts << video.transcript if video.transcript.present?
    parts.join("\n\n---\n\n")
  end

  def extract_video_metadata(video)
    prompt = <<~PROMPT
      Extract metadata from this YouTube video. The speaker/author should be the person featured
      in the video (guest, presenter, lecturer), NOT the channel or interviewer.

      Channel: #{video.channel}
      Title: #{video.title}
      Published: #{video.published_at}

      Description:
      #{video.description.to_s.truncate(2000)}

      Transcript excerpt:
      #{video.transcript.to_s.truncate(8000)}
    PROMPT

    LLM.chat
       .with_schema(VideoMetadataSchema)
       .ask(prompt)
       .content
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

    normalized_url = YoutubeClient.normalize_url(video_url)
    return if normalized_url.blank?
    return if Article.exists?(url: normalized_url)

    Article.create!(url: normalized_url)
  end

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

    LLM.chat
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
    @article.find_similar_and_absorb!
    @article.generate_searches!
    broadcast_update

    GenerateInsightsJob.perform_later(@article)
  end

  def extract_metadata(text)
    prompt = <<~PROMPT
      Extract metadata from this article.

      URL: #{@article.url}

      Content:
      #{text.truncate(10_000)}
    PROMPT

    LLM.chat
       .with_schema(ArticleMetadataSchema)
       .ask(prompt)
       .content
  end

  def generate_summary(text)
    LLM.chat
       .with_instructions(SUMMARY_INSTRUCTIONS)
       .with_schema(ArticleSummarySchema)
       .ask(text.truncate(10_000))
       .content["summary"]
  end

  def broadcast_update
    similar_items = @article.complete? ? build_similar_items : []

    if @old_slug.present? && @article.slug != @old_slug
      new_path = Rails.application.routes.url_helpers.article_path(@article)
      Turbo::StreamsChannel.broadcast_stream_to(
        "article_#{@article.id}",
        content: "<turbo-stream action=\"redirect\" url=\"#{new_path}\"></turbo-stream>"
      )
    end

    Turbo::StreamsChannel.broadcast_replace_to(
      "article_#{@article.id}",
      target: "article_content",
      partial: "articles/content",
      locals: { article: @article, similar_items: }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "articles",
      target: @article,
      partial: "articles/article",
      locals: { article: @article }
    )

    @article.search_articles.includes(:search).find_each do |sa|
      Turbo::StreamsChannel.broadcast_replace_to(
        "search_#{sa.search_id}",
        target: @article,
        partial: "articles/article",
        locals: { article: @article }
      )
    end
  end

  def build_similar_items
    exclude_items = [@article] + @article.insights.to_a

    SimilarItemsQuery.new(
      embedding: @article.embedding,
      limit: 8,
      exclude: exclude_items
    ).call
  end

  def notify_searches_of_resolution
    return unless @article

    @article.containing_searches.searching.find_each do |search|
      HydrateSearchJob.perform_later(search) if search.ready_to_hydrate?
    end
  end
end
