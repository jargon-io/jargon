# frozen_string_literal: true

module ApplicationHelper
  def safe_html(text)
    sanitize(text, tags: %w[strong])
  end
end
