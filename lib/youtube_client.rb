# frozen_string_literal: true

class YoutubeClient
  URL_REGEX = %r{(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([a-zA-Z0-9_-]{11})}

  # Public key embedded in all YouTube pages - not a secret
  INNERTUBE_PUBLIC_API_KEY = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
  INNERTUBE_URL = "https://www.youtube.com/youtubei/v1/player?key=#{INNERTUBE_PUBLIC_API_KEY}"
  INNERTUBE_CONTEXT = { "client" => { "clientName" => "WEB", "clientVersion" => "2.20240101.00.00" } }.freeze

  VideoInfo = Struct.new(:title, :transcript, keyword_init: true)

  def self.youtube_url?(url)
    url.to_s.match?(URL_REGEX)
  end

  def fetch(url)
    video_id = extract_video_id(url)
    return nil unless video_id

    player_data = fetch_player_data(video_id)

    VideoInfo.new(
      title: player_data.dig("videoDetails", "title"),
      transcript: extract_transcript(player_data)
    )
  rescue StandardError => e
    Rails.logger.warn("YoutubeClient#fetch failed: #{e.message}")
    nil
  end

  private

  def extract_video_id(url)
    url.to_s.match(URL_REGEX)&.[](1)
  end

  def fetch_player_data(video_id)
    response = HTTPX.post(INNERTUBE_URL, json: { "context" => INNERTUBE_CONTEXT, "videoId" => video_id })
    JSON.parse(response.body.to_s)
  end

  def extract_transcript(player_data)
    tracks = player_data.dig("captions", "playerCaptionsTracklistRenderer", "captionTracks")
    return nil if tracks.blank?

    transcript_url = tracks.first["baseUrl"]
    fetch_transcript_text(transcript_url)
  end

  def fetch_transcript_text(transcript_url)
    response = HTTPX.get(transcript_url)
    return nil unless response.status == 200

    body = response.body.to_s
    return nil if body.empty?

    texts = body.scan(%r{<text[^>]*>([^<]+)</text>}).flatten
    texts.map { |t| CGI.unescapeHTML(CGI.unescapeHTML(t)) }.join(" ").gsub(/\s+/, " ").strip.presence
  end
end
