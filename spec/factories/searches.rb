# frozen_string_literal: true

FactoryBot.define do
  factory :search do
    sequence(:query) { |n| "How does topic #{n} work?" }
    status { :complete }

    trait :pending do
      status { :pending }
    end

    trait :searching do
      status { :searching }
    end

    trait :with_source_article do
      association :source, factory: :article
    end
  end
end
