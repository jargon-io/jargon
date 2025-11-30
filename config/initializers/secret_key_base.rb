# frozen_string_literal: true

# Allow SECRET_KEY_BASE from environment for containerized deployments
# without requiring Rails credentials
Rails.application.config.secret_key_base = ENV["SECRET_KEY_BASE"] if ENV["SECRET_KEY_BASE"].present?
