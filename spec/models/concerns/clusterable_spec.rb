# frozen_string_literal: true

require "rails_helper"

RSpec.describe Clusterable do
  let(:embedding) { Array.new(1536, 0.1) }

  before { stub_llm }

  describe "#cluster_if_similar!" do
    context "with articles" do
      it "clusters articles with very similar titles" do
        article1 = create(:article, title: "Machine Learning Advances", embedding:)
        article2 = create(:article, title: "Machine Learning Advances", embedding:)

        article2.cluster_if_similar!

        expect(article1.reload.cluster).to eq(article2.reload.cluster)
        expect(Cluster.count).to eq(1)
      end

      it "does not cluster articles with different titles" do
        create(:article, title: "Machine Learning", embedding:)
        article2 = create(:article, title: "Quantum Computing", embedding:)

        article2.cluster_if_similar!

        expect(article2.cluster).to be_nil
        expect(Cluster.count).to eq(0)
      end

      it "does not cluster articles without embeddings" do
        article = create(:article, embedding: nil)

        article.cluster_if_similar!

        expect(article.cluster).to be_nil
      end

      it "adds to existing cluster when titles match" do
        create(:article, title: "Same Topic", embedding:)
        article2 = create(:article, title: "Same Topic", embedding:)
        article2.cluster_if_similar!

        # Cluster now exists with embedding
        cluster = Cluster.first
        cluster.update!(embedding:, name: "Same Topic")

        article3 = create(:article, title: "Same Topic", embedding:)
        article3.cluster_if_similar!

        expect(Cluster.count).to eq(1)
        expect(cluster.reload.member_count).to eq(3)
      end
    end

    context "with insights" do
      let(:article1) { create(:article) }
      let(:article2) { create(:article) }

      it "clusters similar insights from different articles" do
        insight1 = create(:insight, article: article1, embedding:)
        insight2 = create(:insight, article: article2, embedding:)

        insight2.cluster_if_similar!

        expect(insight1.reload.cluster).to eq(insight2.reload.cluster)
      end

      it "does not cluster insights from the same article" do
        create(:insight, article: article1, embedding:)
        insight2 = create(:insight, article: article1, embedding:)

        insight2.cluster_if_similar!

        expect(insight2.cluster).to be_nil
      end
    end
  end

  describe "#title_similarity" do
    let(:article) { build(:article) }

    it "returns 1.0 for identical titles" do
      expect(article.send(:title_similarity, "Hello World", "Hello World")).to eq(1.0)
    end

    it "returns 1.0 for titles differing only in case/punctuation" do
      expect(article.send(:title_similarity, "Hello, World!", "hello world")).to eq(1.0)
    end

    it "returns high similarity for minor differences" do
      similarity = article.send(:title_similarity, "Machine Learning Today", "Machine Learning")
      expect(similarity).to be > 0.7
    end

    it "returns low similarity for different titles" do
      similarity = article.send(:title_similarity, "Machine Learning", "Quantum Physics")
      expect(similarity).to be < 0.5
    end

    it "handles blank titles" do
      expect(article.send(:title_similarity, "", "Hello")).to eq(0.0)
      expect(article.send(:title_similarity, nil, "Hello")).to eq(0.0)
    end
  end
end
