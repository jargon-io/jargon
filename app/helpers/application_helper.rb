# frozen_string_literal: true

module ApplicationHelper
  INTERNAL_LINK_PATTERN = /\[([^\]]+)\]\((insight):([a-z0-9-]+)\)/

  def safe_html(text)
    sanitize(text, tags: %w[strong])
  end

  def render_content(text, current_item: nil)
    return "" if text.blank?

    current_key = current_item&.slug_with_class

    processed = text.gsub(INTERNAL_LINK_PATTERN) do
      link_text = ::Regexp.last_match(1)
      type = ::Regexp.last_match(2)
      slug = ::Regexp.last_match(3)
      target_key = "#{type}:#{slug}"

      if target_key == current_key
        link_text
      else
        path = "/#{type.pluralize}/#{slug}"
        %(<a href="#{path}" class="text-link">#{link_text}</a>)
      end
    end

    sanitize(processed, tags: %w[strong a], attributes: %w[href class])
  end

  def icon_name_for(item)
    case item
    when Article
      if item.has_children?
        "articles"
      elsif item.paper?
        "paper"
      elsif item.video?
        "video"
      else
        "article"
      end
    when Insight
      "insight"
    when Search
      "search"
    end
  end

  def page_icon(item)
    icon = icon_name_for(item)
    image_tag("#{icon}.png", class: "w-16 h-16", alt: "")
  end

  def card_icon(item)
    icon = icon_name_for(item)
    image_tag("#{icon}.png", class: "w-12 h-12", alt: "")
  end
end
