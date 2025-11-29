# frozen_string_literal: true

require "open3"

class Crawl4aiClient
  class CrawlError < StandardError; end

  def crawl(url)
    stdout, stderr, status = Open3.capture3("crwl", url, "-o", "markdown-fit")
    raise CrawlError, "crawl4ai failed: #{stderr}" unless status.success?

    stdout
  end
end
