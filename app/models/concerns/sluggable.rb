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

    def resolve_identifier(identifier)
      find_by(slug: identifier) || find_by(nanoid: identifier)
    end

    def resolve_identifier!(identifier)
      resolve_identifier(identifier) || raise(ActiveRecord::RecordNotFound)
    end
  end

  included do
    before_validation :generate_slug
    validates :slug, uniqueness: true, allow_nil: true
  end

  def to_param
    slug || nanoid
  end

  def slug_with_class
    "#{self.class.name.underscore}:#{slug || nanoid}"
  end

  private

  def generate_slug
    return if slug.present?

    base_slug = compute_base_slug
    self.slug = resolve_slug_collisions(base_slug) if base_slug
  end

  def compute_base_slug
    base =
      if self.class.slug_method.is_a?(Proc)
        instance_exec(&self.class.slug_method)
      else
        send(self.class.slug_method)
      end

    return nil unless base

    base.parameterize.first(50)
  end

  def resolve_slug_collisions(base_slug)
    candidate = base_slug

    candidate = "#{base_slug}-#{SecureRandom.hex(4)}" while self.class.exists?(slug: candidate)

    candidate
  end
end
