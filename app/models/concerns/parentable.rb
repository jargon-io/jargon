# frozen_string_literal: true

module Parentable
  extend ActiveSupport::Concern

  THRESHOLDS = {
    "Article" => 0.3,   # Looser threshold, but requires title match + LLM confirmation
    "Insight" => 0.25   # Topical similarity
  }.freeze

  TITLE_SIMILARITY_THRESHOLD = 0.7

  included do
    belongs_to :parent, class_name: name, optional: true

    has_many :children, class_name: name, foreign_key: :parent_id, dependent: :nullify, inverse_of: :parent

    validate :parent_cannot_have_parent
    validate :children_cannot_have_children

    scope :roots, -> { where(parent_id: nil) }
    scope :children, -> { where.not(parent_id: nil) }
    scope :parents_only, -> { roots.joins(:children).distinct }

    class_attribute :_synthesized_parent_attributes_proc
  end

  class_methods do
    def synthesized_parent_attributes(proc = nil, &block)
      self._synthesized_parent_attributes_proc = proc || block
    end
  end

  def child?
    parent_id.present?
  end

  def parent?
    children.any?
  end

  def siblings
    return self.class.none unless parent

    parent.children.where.not(id:)
  end

  def find_similar_and_absorb!
    return if embedding.blank?
    return if child?

    threshold = THRESHOLDS.fetch(self.class.name)
    match = find_parent_match(threshold) || find_peer_match(threshold)

    return unless match

    if match.parent?
      become_child_of!(match)
    elsif match.child?
      become_child_of!(match.parent)
    else
      create_parent_with!(match)
    end
  end

  def become_child_of!(new_parent)
    update!(parent: new_parent)
    new_parent.regenerate_metadata!
  end

  def create_parent_with!(other)
    new_parent = self.class.new(synthesized_parent_attributes)
    new_parent.children = [self, other]
    new_parent.save!
    new_parent.regenerate_metadata!
  end

  def regenerate_metadata!
    raise NotImplementedError, "#{self.class} must implement #regenerate_metadata!"
  end

  def synthesized_parent_attributes
    proc = self.class._synthesized_parent_attributes_proc
    raise NotImplementedError, "#{self.class} must define synthesized_parent_attributes" unless proc

    proc.call(self)
  end

  private

  def find_parent_match(threshold)
    self.class
        .parents_only
        .where.not(id:)
        .where.not(embedding: nil)
        .nearest_neighbors(:embedding, embedding, distance: "cosine")
        .first
        &.then { |p| similar_enough?(p, threshold) ? p : nil }
  end

  def find_peer_match(threshold)
    scope = self.class
                .roots
                .where.not(id:)
                .where.not(embedding: nil)

    # Don't group insights from the same article
    scope = scope.where.not(article_id:) if is_a?(Insight)

    scope.nearest_neighbors(:embedding, embedding, distance: "cosine")
         .first
         &.then { |i| similar_enough?(i, threshold) ? i : nil }
  end

  def similar_enough?(match, threshold)
    return false unless match
    return false unless match.neighbor_distance < threshold

    return articles_same_content?(match, match.neighbor_distance) if is_a?(Article)

    true
  end

  def articles_same_content?(other, embedding_distance)
    title_sim = title_similarity(title, other.title)

    effective_threshold = embedding_distance < 0.05 ? 0.5 : TITLE_SIMILARITY_THRESHOLD

    return false unless title_sim >= effective_threshold

    llm_confirms_same_article?(other)
  end

  def llm_confirms_same_article?(other)
    prompt = <<~PROMPT
      Are these two articles about the SAME specific content (same paper, same news story, same essay)?
      Not just the same topic - they must be the same underlying work, possibly from different sources.

      Article 1:
      - Title: #{title}
      - Author: #{respond_to?(:author) ? author.presence || 'Unknown' : 'Unknown'}
      - Summary: #{summary.to_s.truncate(500) if respond_to?(:summary)}

      Article 2:
      - Title: #{other.title}
      - Author: #{other.respond_to?(:author) ? other.author.presence || 'Unknown' : 'Unknown'}
      - Summary: #{other.summary.to_s.truncate(500) if other.respond_to?(:summary)}
    PROMPT

    response = LLM.chat
                  .with_schema(ArticleSamenessSchema)
                  .ask(prompt)

    response.content["same_article"] == true
  rescue StandardError => e
    Rails.logger.error("LLM article comparison failed: #{e.message}")
    false
  end

  def title_similarity(a, b)
    return 0.0 if a.blank? || b.blank?

    a_normalized = a.downcase.gsub(/[^\w\s]/, "")
    b_normalized = b.downcase.gsub(/[^\w\s]/, "")

    return 1.0 if a_normalized == b_normalized

    longer = [a_normalized.length, b_normalized.length].max.to_f
    return 0.0 if longer.zero?

    distance = levenshtein_distance(a_normalized, b_normalized)
    1.0 - (distance / longer)
  end

  def levenshtein_distance(s, t)
    m = s.length
    n = t.length

    return n if m.zero?
    return m if n.zero?

    d = Array.new(m + 1) { |i| i }
    x = nil

    (1..n).each do |j|
      x = Array.new(m + 1)
      x[0] = j

      (1..m).each do |i|
        cost = s[i - 1] == t[j - 1] ? 0 : 1
        x[i] = [x[i - 1] + 1, d[i] + 1, d[i - 1] + cost].min
      end

      d = x
    end

    x[m]
  end

  def parent_cannot_have_parent
    return unless parent_id.present? && parent&.parent_id.present?

    errors.add(:parent, "cannot have a parent (flat hierarchy only)")
  end

  def children_cannot_have_children
    return unless parent_id.present? && children.exists?

    errors.add(:base, "children cannot have children")
  end
end
