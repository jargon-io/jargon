# frozen_string_literal: true

FactoryBot.define do
  factory :topic do
    phrase { "machine learning" }
    association :topicable, factory: :article
  end
end
