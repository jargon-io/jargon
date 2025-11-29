# frozen_string_literal: true

class Insight < ApplicationRecord
  include Sluggable
  include Clusterable
  include Embeddable
  include NormalizesMarkup
  include Topicable
  include Linkable
  include ResearchThreadGeneratable

  slug -> { title.presence || "untitled" }

  normalizes_markup :body, :snippet

  embeddable :body

  has_neighbors :embedding

  belongs_to :article

  enum :status, { pending: 0, complete: 1, failed: 2 }

  after_destroy_commit -> { CleanupDeadLinksJob.perform_later(slug) }

  def topic_source_text
    "#{title}\n\n#{body}"
  end

  def research_thread_context
    "Title: #{title}\nBody: #{body}\nSnippet: #{snippet}"
  end
end
