# frozen_string_literal: true

module BroadcastHelper
  def subscribe_to(record)
    turbo_stream_from(record)
  end
end
