# frozen_string_literal: true

require "rails_helper"

RSpec.describe IngestArticleJob do
  let(:article) { create(:article, :pending) }
  let(:article_text) { "This is the full article content with enough text to be considered complete." * 20 }

  def stub_web_ingestion
    stub_llm

    # Stub Exa client
    allow_any_instance_of(ExaClient).to receive(:crawl).and_return({
                                                                     "results" => [{ "text" => article_text, "image" => "https://example.com/image.jpg" }]
                                                                   })

    # Set up chat responses based on schema
    chat = stub_llm_chat
    call_count = 0
    allow(chat).to receive(:ask) do
      call_count += 1
      content = case call_count
                when 1 then { "content_type" => "full", "is_academic_paper" => false }
                when 2 then { "title" => "Article Title", "author" => "John Doe", "published_at" => "2024-01-15" }
                when 3 then { "summary" => "A concise summary." }
                else { "queries" => [], "topics" => [] }
                end
      instance_double(RubyLLM::Message, content:)
    end

    allow(GenerateInsightsJob).to receive(:perform_later)
  end

  before { stub_web_ingestion }

  it "ingests article content from URL" do
    described_class.perform_now(article.url)

    article.reload
    expect(article.status).to eq("complete")
    expect(article.title).to eq("Article Title")
    expect(article.text).to eq(article_text)
  end

  it "generates summary" do
    described_class.perform_now(article.url)

    expect(article.reload.summary).to eq("A concise summary.")
  end

  it "queues insight generation" do
    described_class.perform_now(article.url)

    expect(GenerateInsightsJob).to have_received(:perform_later).with(article.id)
  end

  context "when content is blocked" do
    before do
      chat = stub_llm_chat
      allow(chat).to receive(:ask).and_return(
        instance_double(RubyLLM::Message, content: { "content_type" => "blocked" })
      )
    end

    it "marks article as failed" do
      described_class.perform_now(article.url)

      expect(article.reload.status).to eq("failed")
    end
  end

  describe "YouTube processing" do
    let(:youtube_article) { create(:article, :pending, url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ") }

    before do
      # Override the default web ingestion stubs
      RSpec::Mocks.space.proxy_for(ExaClient).reset

      stub_llm

      video = Struct.new(:title, :channel, :published_at, :transcript, keyword_init: true).new(
        title: "Video Title",
        channel: "Channel Name",
        published_at: Date.new(2024, 1, 1),
        transcript: "This is the video transcript."
      )
      allow_any_instance_of(YoutubeClient).to receive(:fetch).and_return(video)
      allow(GenerateInsightsJob).to receive(:perform_later)
    end

    it "processes as video content" do
      described_class.perform_now(youtube_article.url)

      youtube_article.reload
      expect(youtube_article.content_type).to eq("video")
      expect(youtube_article.title).to eq("Video Title")
      expect(youtube_article.text).to eq("This is the video transcript.")
    end
  end
end
