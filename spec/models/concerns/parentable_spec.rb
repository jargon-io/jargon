# frozen_string_literal: true

require "rails_helper"

RSpec.describe Parentable do
  let(:embedding) { Array.new(1536) { rand(-1.0..1.0) } }

  before { stub_llm }

  describe "associations" do
    it "allows articles to have parent-child relationships" do
      parent = create(:article)
      child = create(:article, parent:)

      expect(child.parent).to eq(parent)
      expect(parent.children).to include(child)
    end

    it "allows insights to have parent-child relationships" do
      parent_insight = create(:insight)
      child_insight = create(:insight, parent: parent_insight)

      expect(child_insight.parent).to eq(parent_insight)
      expect(parent_insight.children).to include(child_insight)
    end
  end

  describe "#parent?" do
    it "returns true when article has children" do
      parent = create(:article)
      create(:article, parent:)

      expect(parent.parent?).to be true
    end

    it "returns false when article has no children" do
      article = create(:article)

      expect(article.parent?).to be false
    end

    it "returns true for unsaved parent with assigned children" do
      child1 = create(:article)
      child2 = create(:article)
      parent = Article.new(status: :complete)
      parent.children = [child1, child2]

      expect(parent.parent?).to be true
    end
  end

  describe "#child?" do
    it "returns true when article has a parent" do
      parent = create(:article)
      child = create(:article, parent:)

      expect(child.child?).to be true
    end

    it "returns false when article has no parent" do
      article = create(:article)

      expect(article.child?).to be false
    end
  end

  describe "scopes" do
    let!(:standalone) { create(:article) }
    let!(:parent) { create(:article) }
    let!(:child1) { create(:article, parent:) }
    let!(:child2) { create(:article, parent:) }

    describe ".roots" do
      it "returns articles without parents" do
        expect(Article.roots).to include(standalone, parent)
        expect(Article.roots).not_to include(child1, child2)
      end
    end

    describe ".parents_only" do
      it "returns only articles that have children" do
        expect(Article.parents_only).to include(parent)
        expect(Article.parents_only).not_to include(standalone, child1, child2)
      end
    end
  end

  describe "validations" do
    it "prevents nested parents (flat hierarchy)" do
      grandparent = create(:article)
      parent = create(:article, parent: grandparent)
      child = build(:article, parent:)

      expect(child).not_to be_valid
      expect(child.errors[:parent]).to include("cannot have a parent (flat hierarchy only)")
    end

    it "prevents children from having children" do
      parent = create(:article)
      child = create(:article, parent:)
      grandchild = build(:article, parent: child)

      expect(grandchild).not_to be_valid
      expect(grandchild.errors[:parent]).to include("cannot have a parent (flat hierarchy only)")
    end
  end

  describe "#create_parent_with!" do
    let(:article1) { create(:article, title: "Article One", summary: "Summary one", embedding:) }
    let(:article2) { create(:article, title: "Article Two", summary: "Summary two", embedding:) }

    it "creates a new parent and makes both articles children" do
      article1.create_parent_with!(article2)

      article1.reload
      article2.reload

      expect(article1.parent).to eq(article2.parent)
      expect(article1.parent).to be_present
      expect(article1.parent.parent?).to be true
    end

    it "creates parent without URL" do
      article1.create_parent_with!(article2)

      parent = article1.reload.parent
      expect(parent.url).to be_nil
    end
  end

  describe "#become_child_of!" do
    let(:parent) { create(:article, embedding:) }
    let(:child) { create(:article, embedding:) }

    before do
      # Make parent a real parent first
      create(:article, parent:)
    end

    it "sets the parent relationship" do
      child.become_child_of!(parent)

      expect(child.reload.parent).to eq(parent)
    end
  end

  describe "title_similarity" do
    let(:article) { create(:article) }

    it "returns 1.0 for identical titles" do
      similarity = article.send(:title_similarity, "Hello World", "Hello World")

      expect(similarity).to eq(1.0)
    end

    it "returns 1.0 for case-insensitive matches" do
      similarity = article.send(:title_similarity, "Hello World", "hello world")

      expect(similarity).to eq(1.0)
    end

    it "returns high similarity for minor differences" do
      similarity = article.send(:title_similarity, "As We May Think", "As We May Think!")

      expect(similarity).to be > 0.9
    end

    it "returns low similarity for different titles" do
      similarity = article.send(:title_similarity, "Hello World", "Goodbye Universe")

      expect(similarity).to be < 0.5
    end

    it "returns 0 for blank titles" do
      expect(article.send(:title_similarity, "", "Hello")).to eq(0.0)
      expect(article.send(:title_similarity, "Hello", "")).to eq(0.0)
      expect(article.send(:title_similarity, nil, "Hello")).to eq(0.0)
    end
  end
end
