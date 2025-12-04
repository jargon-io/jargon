# frozen_string_literal: true

class HomeFeedQuery
  FeedItem = Data.define(:subject, :show_searches) do
    delegate :created_at, to: :subject
  end

  def initialize(limit: 25)
    @limit = limit
  end

  def call
    items = subjects_with_searches + standalone_articles + standalone_searches
    items.sort_by { |i| -i.created_at.to_i }.first(@limit)
  end

  private

  def subjects_with_searches
    searches = Search.not_pending
                     .where(source_type: %w[Article Insight])
                     .includes(source: %i[article searches])
                     .to_a

    subjects = searches.filter_map(&:source).uniq
    subjects.map { |subject| FeedItem.new(subject:, show_searches: true) }
  end

  def standalone_articles
    Article.complete
           .roots
           .manual
           .where.not(id: article_subject_ids)
           .order(created_at: :desc)
           .limit(@limit)
           .map { |a| FeedItem.new(subject: a, show_searches: false) }
  end

  def standalone_searches
    Search.not_pending
          .where(source_type: [nil, "Search"])
          .order(created_at: :desc)
          .limit(@limit)
          .map { |s| FeedItem.new(subject: s, show_searches: false) }
  end

  def article_subject_ids
    @article_subject_ids ||= Search.not_pending.where(source_type: "Article").distinct.pluck(:source_id)
  end
end
