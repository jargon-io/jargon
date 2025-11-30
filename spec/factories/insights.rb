# frozen_string_literal: true

FactoryBot.define do
  factory :insight do
    article
    title { "Key Insight" }
    body { "The main takeaway from the article." }
    snippet { "Original text from the source." }
    status { :complete }

    trait :parent do
      after(:create) do |insight|
        create_list(:insight, 2, parent: insight, article: insight.article)
      end
    end
  end
end
