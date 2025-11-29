# frozen_string_literal: true

require "rails_helper"

RSpec.describe Embeddable do
  let(:embedding_vectors) { Array.new(1536, 0.1) }

  before { stub_llm_embed(embedding_vectors) }

  describe "#generate_embedding!" do
    let(:article) { create(:article, summary: "Test summary") }

    it "generates and stores embedding from embeddable field" do
      article.generate_embedding!

      expect(LLM).to have_received(:embed).with("Test summary")
      expect(article.reload.embedding).to eq(embedding_vectors)
    end

    it "skips blank text" do
      article.update!(summary: nil)

      article.generate_embedding!

      expect(LLM).not_to have_received(:embed)
    end

    context "with insight" do
      let(:insight) { create(:insight, body: "Insight body text") }

      it "uses the configured embeddable field" do
        insight.generate_embedding!

        expect(LLM).to have_received(:embed).with("Insight body text")
      end
    end

    context "with topic" do
      let(:topic) { create(:topic, phrase: "machine learning") }

      it "uses phrase as embeddable field" do
        topic.generate_embedding!

        expect(LLM).to have_received(:embed).with("machine learning")
      end
    end
  end
end
