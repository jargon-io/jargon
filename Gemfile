# frozen_string_literal: true

source "https://rubygems.org"

gem "async-cable"
gem "async-job-adapter-active_job"
gem "dalli"
gem "dotenv"
gem "falcon"
gem "httpx"
gem "importmap-rails"
gem "neighbor"
gem "pg", "~> 1.1"
gem "propshaft"
gem "rails", "~> 8.1.1"
gem "redis"
gem "ruby_llm"
gem "ruby_llm-schema"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "htmlbeautifier"
  gem "rubocop", "1.79.2"
  gem "rubocop-rails", require: false
  gem "ruby-lsp", "0.23.23"
end

group :development do
  gem "web-console"
end
