# frozen_string_literal: true

class VideoMetadataSchema < RubyLLM::Schema
  string :title, description: "Clean video title - remove channel names, episode numbers, and promotional text"
  string :author,
         description: "The speaker, interviewee, or primary person featured (NOT the channel/host unless they are the subject). " \
                      "For interviews, use the guest's name. For talks/lectures, use the presenter's name."
  string :published_at, description: "Publication date in YYYY-MM-DD format if mentioned"
  string :summary,
         description: "200-300 character summary of the video's key idea. State the finding/idea directly. " \
                      "Use <strong> HTML tags to emphasize 1-2 key terms. Edit for clarity if from transcript."
end
