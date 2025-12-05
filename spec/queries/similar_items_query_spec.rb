# frozen_string_literal: true

require "rails_helper"

RSpec.describe SimilarItemsQuery do
  let(:embedding) { Array.new(1536) { rand(-1.0..1.0) } }

  describe "#call" do
    it "returns similar articles and insights sorted by distance" do
      create(:article, :complete, embedding:)
      create(:insight, embedding:)

      results = described_class.new(embedding:, limit: 10).call

      expect(results.size).to be >= 2
    end

    it "excludes specified items" do
      article = create(:article, :complete, embedding:)
      create(:insight, embedding:)

      results = described_class.new(embedding:, limit: 10, exclude: [article]).call

      expect(results).not_to include(article)
    end

    it "respects the limit" do
      5.times { create(:article, :complete, embedding:) }

      results = described_class.new(embedding:, limit: 2).call

      expect(results.size).to be <= 2
    end
  end
end
