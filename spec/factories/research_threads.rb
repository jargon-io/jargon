# frozen_string_literal: true

FactoryBot.define do
  factory :research_thread do
    query { "How does this relate to other work?" }
    status { :pending }

    trait :for_article do
      association :subject, factory: :article
    end

    trait :for_insight do
      association :subject, factory: :insight
    end

    trait :researched do
      status { :researched }
    end
  end
end
