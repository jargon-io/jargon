# frozen_string_literal: true

FactoryBot.define do
  factory :cluster do
    name { "Cluster Name" }
    summary { "Summary of the cluster theme." }
    clusterable_type { "Article" }
    status { :complete }

    trait :for_insights do
      clusterable_type { "Insight" }
      body { "Synthesized insight body." }
      snippet { "Representative snippet." }
    end

    trait :pending do
      status { :pending }
    end
  end
end
