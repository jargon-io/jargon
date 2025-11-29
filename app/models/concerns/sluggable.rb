# frozen_string_literal: true

module Sluggable
  extend ActiveSupport::Concern

  class_methods do
    attr_accessor :slug_method

    def slug(method)
      @slug_method = method
    end

    def by_slug(slug)
      find_by(slug: slug.split(":").last)
    end

    def by_slug!(slug)
      find_by!(slug: slug.split(":").last)
    end
  end

  included do
    before_validation :generate_slug
    validates :slug, presence: true, uniqueness: true
  end

  def to_param
    slug
  end

  def slug_with_class
    "#{self.class.name.underscore}:#{slug}"
  end

  private

  def generate_slug
    return if slug.present? && !should_regenerate_slug?

    base_slug = compute_base_slug
    self.slug = resolve_slug_collisions(base_slug) if base_slug
  end

  def should_regenerate_slug?
    return false unless slug&.start_with?("untitled")

    base = compute_base_slug
    base.present? && !base.start_with?("untitled")
  end

  def compute_base_slug
    base =
      if self.class.slug_method.is_a?(Proc)
        instance_exec(&self.class.slug_method)
      else
        send(self.class.slug_method)
      end

    unless base
      Rails.logger.info("Unable to generate slug for #{self.class}")
      return
    end

    base.parameterize.first(50)
  end

  def resolve_slug_collisions(base_slug)
    candidate = base_slug

    candidate = "#{base_slug}-#{SecureRandom.hex(4)}" while self.class.exists?(slug: candidate)

    candidate
  end
end
