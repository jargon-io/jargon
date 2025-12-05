# frozen_string_literal: true

module Broadcastable
  extend ActiveSupport::Concern

  included do
    after_commit :broadcast_self, if: :broadcastable?
  end

  def broadcastable?
    !Rails.env.test?
  end

  def broadcast_self
    broadcast_page
    broadcast_card
    broadcast_to_parents
  end

  def broadcast_page
    broadcast_replace_later_to(
      self,
      target: page_dom_id,
      partial: page_partial,
      locals: broadcast_locals
    )
  end

  def broadcast_card
    broadcast_replace_later_to(
      self,
      target: card_dom_id,
      partial: card_partial,
      locals: broadcast_locals
    )
  end

  def broadcast_to_parents
    # Override in models with parent relationships
  end

  def page_dom_id
    "#{model_name.singular}_#{id}_page"
  end

  def card_dom_id
    ActionView::RecordIdentifier.dom_id(self)
  end

  def page_partial
    "#{model_name.plural}/#{model_name.singular}_page"
  end

  def card_partial
    "#{model_name.plural}/#{model_name.singular}"
  end

  def broadcast_locals
    { model_name.singular.to_sym => self }
  end
end
