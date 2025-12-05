# frozen_string_literal: true

require "rails_helper"

RSpec.describe IngestArticleJob do
  let(:article) { create(:article, :pending) }
  let(:article_text) { "This is the full article content with enough text to be considered complete." * 20 }

  def stub_web_ingestion
    stub_llm

    # Stub Exa client - must stub .new since initialize calls ENV.fetch
    exa_double = instance_double(ExaClient)
    allow(ExaClient).to receive(:new).and_return(exa_double)
    allow(exa_double).to receive(:crawl).and_return(
      {
        "results" => [{ "text" => article_text, "image" => "https://example.com/image.jpg" }]
      }
    )

    # Set up chat responses based on schema
    chat = stub_llm_chat
    call_count = 0
    allow(chat).to receive(:ask) do
      call_count += 1
      content = case call_count
                when 1 then {
                  "content_type" => "full",
                  "reason" => "Complete article",
                  "full_text_url" => "",
                  "embedded_video_url" => "",
                  "has_meaningful_content" => true,
                  "is_academic_paper" => false
                }
                when 2 then { "title" => "Article Title", "author" => "John Doe", "published_at" => "2024-01-15" }
                when 3 then { "summary" => "A concise summary." }
                else { "queries" => [] }
                end
      instance_double(RubyLLM::Message, content:)
    end

    allow(GenerateInsightsJob).to receive(:perform_later)
  end

  before { stub_web_ingestion }

  it "ingests article content from URL" do
    described_class.perform_now(article)

    article.reload
    expect(article.status).to eq("complete")
    expect(article.title).to eq("Article Title")
    expect(article.text).to eq(article_text)
  end

  it "generates summary" do
    described_class.perform_now(article)

    expect(article.reload.summary).to eq("A concise summary.")
  end

  it "queues insight generation" do
    described_class.perform_now(article)

    expect(GenerateInsightsJob).to have_received(:perform_later).with(article)
  end

  context "when content is blocked" do
    before do
      # Re-stub chat to return blocked content type
      chat = stub_llm_chat
      allow(chat).to receive(:ask).and_return(
        instance_double(
          RubyLLM::Message, content: {
            "content_type" => "blocked",
            "reason" => "Captcha detected",
            "full_text_url" => "",
            "embedded_video_url" => "",
            "has_meaningful_content" => false,
            "is_academic_paper" => false
          }
        )
      )
    end

    it "marks article as failed" do
      described_class.perform_now(article)

      expect(article.reload.status).to eq("failed")
    end
  end

  describe "YouTube processing" do
    let(:youtube_article) { create(:article, :pending, url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ") }

    before do
      stub_llm_chat_sequence(
        { "title" => "Extracted Title", "author" => "Extracted Author", "published_at" => "2024-06-15", "summary" => "Extracted summary" },
        { "queries" => [] }
      )
      stub_llm_embed

      video = YoutubeClient::VideoInfo.new(
        title: "Video Title",
        channel: "Channel Name",
        published_at: Date.new(2024, 1, 1),
        description: "Video description here.",
        transcript: "This is the video transcript."
      )
      allow_any_instance_of(YoutubeClient).to receive(:fetch).and_return(video)
      allow(GenerateInsightsJob).to receive(:perform_later)
    end

    it "processes as video content with LLM-extracted metadata" do
      described_class.perform_now(youtube_article)

      youtube_article.reload
      expect(youtube_article.content_type).to eq("video")
      expect(youtube_article.title).to eq("Extracted Title")
      expect(youtube_article.author).to eq("Extracted Author")
      expect(youtube_article.published_at).to eq(Date.new(2024, 6, 15))
      expect(youtube_article.summary).to eq("Extracted summary")
      expect(youtube_article.text).to eq("Video description here.\n\n---\n\nThis is the video transcript.")
    end

    it "falls back to video metadata when LLM returns blank" do
      stub_llm_chat_sequence(
        { "title" => "", "author" => "", "published_at" => "", "summary" => "" },
        { "queries" => [] }
      )

      described_class.perform_now(youtube_article)

      youtube_article.reload
      expect(youtube_article.title).to eq("Video Title")
      expect(youtube_article.author).to eq("Channel Name")
      expect(youtube_article.published_at).to eq(Date.new(2024, 1, 1))
    end
  end
end
