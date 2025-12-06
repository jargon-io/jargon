# Configure allowed WebSocket origins for Action Cable / Async::Cable.
allowed_origins = ENV["ACTION_CABLE_ALLOWED_ORIGINS"]

Rails.application.config.action_cable.allowed_request_origins =
  if allowed_origins.present?
    allowed_origins.split(",").map(&:strip).reject(&:empty?)
  else
    [
      %r{\Ahttps?://localhost(:\d+)?\z},
      %r{\Ahttps?://127\.0\.0\.1(:\d+)?\z},
      %r{\Ahttps?://host\.docker\.internal(:\d+)?\z}
    ]
  end
