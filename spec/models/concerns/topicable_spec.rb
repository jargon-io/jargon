# frozen_string_literal: true

require "rails_helper"

RSpec.describe Topicable do
  let(:article) { create(:article, title: "AI Research", summary: "About machine learning") }
  let(:topics_response) { { "topics" => ["Pattern Recognition in Nature", "Biological Computing"] } }

  before do
    stub_llm_embed

    chat = stub_llm_chat(default: topics_response)
    allow(chat).to receive(:ask).and_return(
      instance_double(RubyLLM::Message, content: topics_response)
    )
  end

  describe "#generate_topics!" do
    it "creates topics from LLM response" do
      expect { article.generate_topics! }
        .to change { article.topics.count }.by(2)
    end

    it "sets topic phrases from response" do
      article.generate_topics!

      expect(article.topics.pluck(:phrase)).to contain_exactly(
        "Pattern Recognition in Nature",
        "Biological Computing"
      )
    end

    it "generates embeddings for each topic" do
      article.generate_topics!

      expect(LLM).to have_received(:embed).at_least(:twice)
    end

    it "replaces existing topics" do
      article.topics.create!(phrase: "Old Topic")

      article.generate_topics!

      expect(article.topics.pluck(:phrase)).not_to include("Old Topic")
    end
  end
end
