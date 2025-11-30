# frozen_string_literal: true

FactoryBot.define do
  factory :article do
    sequence(:url) { |n| "https://example.com/article-#{n}" }
    title { "Example Article" }
    summary { "A summary of the article content." }
    status { :complete }
    content_type { :full }

    trait :pending do
      status { :pending }
      title { nil }
      summary { nil }
    end

    trait :with_text do
      text { "Full article text content goes here." }
    end

    trait :video do
      content_type { :video }
    end

    trait :partial do
      content_type { :partial }
    end

    trait :parent do
      url { nil }
      after(:create) do |article|
        create_list(:article, 2, parent: article)
      end
    end
  end
end
