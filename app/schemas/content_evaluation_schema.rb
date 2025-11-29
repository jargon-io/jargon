# frozen_string_literal: true

class ContentEvaluationSchema < RubyLLM::Schema
  string :content_type,
         description: "Content classification: full (complete article), partial (incomplete/timestamps/index), " \
                      "abstract (academic abstract with link to full text), video (YouTube/video page), " \
                      "podcast (podcast episode), paywall (login required), blocked (captcha/error)"
  string :reason, description: "Brief explanation of why this classification was chosen"
  string :full_text_url, description: "URL to full text if this is an abstract (leave blank otherwise)"
  string :embedded_video_url, description: "YouTube URL if page contains an embedded video (leave blank otherwise)"
  boolean :has_meaningful_content, description: "Whether there's enough substance to extract insights from"
end
