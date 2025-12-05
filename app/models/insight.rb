# frozen_string_literal: true

class Insight < ApplicationRecord
  include Sluggable
  include Parentable
  include Embeddable
  include NormalizesMarkup
  include Linkable
  include SearchGeneratable
  include Broadcastable

  slug -> { title }

  synthesized_parent_attributes ->(_) { { article: nil, status: :complete } }

  parent_matching threshold: 0.25

  # Don't group insights from the same article
  peer_scope do |scope|
    scope.where.not(article_id:)
  end

  reparents Search, foreign_key: :source_id

  normalizes_markup :body, :snippet

  embeddable :body

  search_context -> { "Title: #{title}\nBody: #{body}\nSnippet: #{snippet}" }

  has_neighbors :embedding

  belongs_to :article, optional: true
  validates :article, presence: true, unless: :has_children?

  enum :status, { pending: 0, complete: 1, failed: 2 }

  after_destroy_commit -> { CleanupDeadLinksJob.perform_later(slug) }

  def sibling_insights
    return [] if embedding.blank?

    if has_children?
      article_ids = children.includes(:article)
                            .flat_map { |c| [c.article&.id, c.article&.parent_id] }
                            .compact
                            .uniq

      excluded_ids = children.pluck(:id) + [id]
    else
      article_ids = [article_id].compact

      excluded_ids = [id]
    end

    return [] if article_ids.empty?

    root_ids = Insight.complete.roots.where(article_id: article_ids).pluck(:id)
    parent_ids = Insight.complete.children.where(article_id: article_ids).pluck(:parent_id)

    Insight.where(id: root_ids + parent_ids)
           .where.not(id: excluded_ids)
           .distinct
           .nearest_neighbors(:embedding, embedding, distance: "cosine")
           .to_a
  end

  def regenerate_metadata!
    return unless has_children?

    update!(ParentSynthesizer.new(children).synthesize)
    generate_embedding!
    generate_searches!

    AddLinksJob.set(wait: 30.seconds).perform_later(self)
  rescue StandardError => e
    Rails.logger.error("Insight parent metadata generation failed: #{e.message}")
  end

  def broadcast_to_parents
    article&.broadcast_self
  end
end
