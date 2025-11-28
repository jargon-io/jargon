# frozen_string_literal: true

class ExaClient
  def initialize
    @base_url = "https://api.exa.ai"
    @api_key = ENV.fetch("EXA_API_KEY", Rails.application.credentials.exa_api_key)
  end

  def crawl(urls:)
    uri = URI.join(@base_url, "/contents")

    json = {
      urls:,
      text: true,
      summary: { query: "Summarize the main idea of the article in 200-300 characters." }
    }

    HTTPX.post(uri, json:, headers:).raise_for_status.json
  end

  def search(query:, category: nil, start_published_date: nil, end_published_date: nil)
    uri = URI.join(@base_url, "/search")

    json = { query: }

    json[:category] = category if category
    json[:startPublishedDate] = start_published_date if start_published_date
    json[:endPublishedDate] = end_published_date if end_published_date
    json[:includeDomains] = domains if domains

    HTTPX.post(uri, json:, headers:).raise_for_status.json
  end

  private

  def headers
    {
      "Authorization" => "Bearer #{@api_key}",
      "Content-Type" => "application/json"
    }
  end
end
