# frozen_string_literal: true

module Parentable
  extend ActiveSupport::Concern

  included do
    belongs_to :parent, class_name: name, optional: true

    has_many :children, class_name: name, foreign_key: :parent_id, dependent: :nullify, inverse_of: :parent

    validate :parent_cannot_have_parent
    validate :children_cannot_have_children

    after_save :reparent_references, if: -> { saved_change_to_parent_id? && parent_id.present? }

    scope :roots, -> { where(parent_id: nil) }
    scope :children, -> { where.not(parent_id: nil) }
    scope :parents_only, -> { roots.joins(:children).distinct }

    class_attribute :_synthesized_parent_attributes_proc
    class_attribute :_parent_matching_threshold
    class_attribute :_parent_matching_check
    class_attribute :_peer_scope_proc
    class_attribute :_reparentable_references, default: []
  end

  class_methods do
    # DSL: Configure how parent/peer matching works
    #
    #   parent_matching threshold: 0.3 do |candidate, distance|
    #     same_content?(candidate)
    #   end
    #
    def parent_matching(threshold:, &block)
      self._parent_matching_threshold = threshold
      self._parent_matching_check = block
    end

    # DSL: Configure peer search scope filtering
    #
    #   peer_scope do |scope|
    #     scope.where.not(article_id: article_id)
    #   end
    #
    def peer_scope(&block)
      self._peer_scope_proc = block
    end

    # DSL: Configure what references to reparent when becoming a child
    #
    #   reparents Insight, foreign_key: :article_id
    #   reparents SearchArticle, foreign_key: :article_id
    #
    def reparents(model_class, foreign_key:)
      self._reparentable_references += [{ model_class:, foreign_key: }]
    end

    # DSL: Configure attributes for synthesized parent records
    #
    #   synthesized_parent_attributes -> { { url: nil, status: :complete } }
    #
    def synthesized_parent_attributes(proc = nil, &block)
      self._synthesized_parent_attributes_proc = proc || block
    end
  end

  def has_parent? # rubocop:disable Naming/PredicatePrefix
    parent_id.present?
  end

  def has_children? # rubocop:disable Naming/PredicatePrefix
    children.any?
  end

  def siblings
    return self.class.none unless parent

    parent.children.where.not(id:)
  end

  def find_similar_and_absorb!
    return if embedding.blank?
    return if has_parent?

    match = find_parent_match || find_peer_match

    return unless match

    if match.has_children?
      become_child_of!(match)
    elsif match.has_parent?
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

  def find_parent_match
    threshold = self.class._parent_matching_threshold
    return nil unless threshold

    self.class
        .parents_only
        .where.not(id:)
        .where.not(embedding: nil)
        .nearest_neighbors(:embedding, embedding, distance: "cosine")
        .first
        &.then { |p| similar_enough?(p) ? p : nil }
  end

  def find_peer_match
    threshold = self.class._parent_matching_threshold
    return nil unless threshold

    scope = self.class
                .roots
                .where.not(id:)
                .where.not(embedding: nil)

    # Apply model-specific peer scope filtering
    scope = instance_exec(scope, &self.class._peer_scope_proc) if self.class._peer_scope_proc

    scope.nearest_neighbors(:embedding, embedding, distance: "cosine")
         .first
         &.then { |p| similar_enough?(p) ? p : nil }
  end

  def similar_enough?(candidate)
    return false unless candidate

    threshold = self.class._parent_matching_threshold
    distance = candidate.neighbor_distance

    return false unless distance < threshold

    # If model provides additional matching check, run it
    check = self.class._parent_matching_check
    return true unless check

    instance_exec(candidate, distance, &check)
  end

  def parent_cannot_have_parent
    return unless parent_id.present? && parent&.parent_id.present?

    errors.add(:parent, "cannot have a parent (flat hierarchy only)")
  end

  def children_cannot_have_children
    return unless parent_id.present? && children.exists?

    errors.add(:base, "children cannot have children")
  end

  def reparent_references
    self.class._reparentable_references.each do |ref|
      ref[:model_class]
        .where(ref[:foreign_key] => id)
        .update_all(ref[:foreign_key] => parent_id) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
