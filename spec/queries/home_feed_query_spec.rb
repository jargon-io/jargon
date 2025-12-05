# frozen_string_literal: true

require "rails_helper"

RSpec.describe HomeFeedQuery do
  describe "#call" do
    context "with subjects_with_searches" do
      it "preloads searches for articles without N+1" do
        # Create articles with searches pointing to them
        articles = create_list(:article, 3)
        articles.each do |article|
          create_list(:search, 2, source: article)
        end

        # This will raise Bullet::Notification::UnoptimizedQueryError if N+1 detected
        items = described_class.new(limit: 25).call

        # Verify we got feed items and can access searches without additional queries
        article_items = items.select { |i| i.subject.is_a?(Article) }
        expect(article_items).not_to be_empty

        # Access searches on each article - would trigger N+1 without preloading
        article_items.each do |item|
          item.subject.searches.select(&:complete?)
        end
      end
    end

    context "with standalone_articles" do
      it "loads root articles without eager loading parent" do
        # Create root articles (no parent)
        create_list(:article, 3, origin: :manual)

        # This will raise if we're eager loading :parent on roots (wasteful)
        items = described_class.new(limit: 25).call

        expect(items).not_to be_empty
      end
    end

    context "with insight sources" do
      it "preloads parent for insights without N+1" do
        # Create insights with parent relationships and searches pointing to them
        3.times do
          parent_insight = create(:insight, :parent)
          child = parent_insight.children.first
          create(:search, source: child)
        end

        # This will raise Bullet::Notification::UnoptimizedQueryError if N+1 detected
        items = described_class.new(limit: 25).call

        # Verify we got feed items with parent insights (rolled up from children)
        insight_items = items.select { |i| i.subject.is_a?(Insight) }
        expect(insight_items).not_to be_empty
      end
    end

    context "with mixed feed" do
      it "handles all feed item types without N+1" do
        # Articles with searches as source
        article = create(:article)
        create(:search, source: article)

        # Standalone articles
        create(:article, origin: :manual)

        # Standalone searches (no source)
        create(:search, source: nil)

        items = described_class.new(limit: 25).call

        expect(items.size).to be >= 3
      end
    end
  end
end
