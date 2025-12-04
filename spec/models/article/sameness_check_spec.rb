# frozen_string_literal: true

require "rails_helper"

RSpec.describe Article::SamenessCheck do
  before { stub_llm }

  describe "#same?" do
    let(:article) { create(:article, title: "Hello World", summary: "A greeting") }
    let(:candidate) { create(:article, title: "Hello World", summary: "A greeting") }

    it "returns true when titles match and LLM confirms" do
      stub_llm_response("same_article" => true, "reason" => "Same content")

      check = described_class.new(article, candidate, embedding_distance: 0.1)

      expect(check.same?).to be true
    end

    it "returns false when LLM rejects" do
      stub_llm_response("same_article" => false, "reason" => "Different content")

      check = described_class.new(article, candidate, embedding_distance: 0.1)

      expect(check.same?).to be false
    end

    it "returns false when titles are too different" do
      candidate.update!(title: "Goodbye Universe")

      check = described_class.new(article, candidate, embedding_distance: 0.1)

      expect(check.same?).to be false
    end

    it "uses lower title threshold when embedding distance is very small" do
      candidate.update!(title: "Hello") # Short but somewhat similar

      stub_llm_response("same_article" => true, "reason" => "Same")

      # With very low embedding distance (< 0.05), title threshold drops to 0.5
      check = described_class.new(article, candidate, embedding_distance: 0.04)

      # Title similarity of "Hello World" vs "Hello" should be around 0.45
      # which is below even the relaxed 0.5 threshold
      expect(check.same?).to be false
    end
  end

  describe "title_similarity (via same? behavior)" do
    let(:article) { create(:article, title: "Hello World", summary: "Test") }

    it "considers identical titles similar" do
      candidate = create(:article, title: "Hello World", summary: "Test")
      stub_llm_response("same_article" => true, "reason" => "Same")

      check = described_class.new(article, candidate, embedding_distance: 0.1)

      expect(check.same?).to be true
    end

    it "considers case-insensitive matches similar" do
      candidate = create(:article, title: "hello world", summary: "Test")
      stub_llm_response("same_article" => true, "reason" => "Same")

      check = described_class.new(article, candidate, embedding_distance: 0.1)

      expect(check.same?).to be true
    end

    it "considers minor punctuation differences similar" do
      candidate = create(:article, title: "Hello World!", summary: "Test")
      stub_llm_response("same_article" => true, "reason" => "Same")

      check = described_class.new(article, candidate, embedding_distance: 0.1)

      expect(check.same?).to be true
    end

    it "rejects very different titles" do
      candidate = create(:article, title: "Goodbye Universe", summary: "Test")

      check = described_class.new(article, candidate, embedding_distance: 0.1)

      # Should fail before even calling LLM
      expect(check.same?).to be false
    end
  end

  private

  def stub_llm_response(content)
    allow(LLM).to receive_message_chain(:chat, :with_schema, :ask)
      .and_return(double(content:))
  end
end
