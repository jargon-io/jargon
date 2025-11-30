# frozen_string_literal: true

class CleanupDeadLinksJob < ApplicationJob
  queue_as :default

  # Fields that may contain internal links (only insights are link targets)
  LINKABLE_FIELDS = {
    "Article" => [:summary],
    "Insight" => %i[body snippet]
  }.freeze

  def perform(slug)
    target_pattern = "(insight:#{slug})"
    link_pattern = /\[([^\]]+)\]\(insight:#{Regexp.escape(slug)}\)/

    LINKABLE_FIELDS.each do |klass_name, fields|
      klass = klass_name.constantize
      where_clause = fields.map { |f| "#{f} LIKE ?" }.join(" OR ")
      like_values = fields.map { "%#{target_pattern}%" }

      klass.where(where_clause, *like_values).find_each do |record|
        fields.each do |field|
          content = record.send(field)
          next unless content&.include?(target_pattern)

          record.update(field => content.gsub(link_pattern, '\1'))
        end
      end
    end
  end
end
