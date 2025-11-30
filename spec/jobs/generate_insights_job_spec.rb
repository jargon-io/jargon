# frozen_string_literal: true

require "rails_helper"

RSpec.describe GenerateInsightsJob do
  let(:article) { create(:article, :with_text) }

  let(:insights_response) do
    {
      "insights" => [
        { "title" => "Key Finding", "body" => "The main takeaway.", "snippet" => "Original text." },
        { "title" => "Secondary Point", "body" => "Another insight.", "snippet" => "More text." }
      ],
      "queries" => []
    }
  end

  before do
    stub_llm_embed
    stub_llm_chat(default: insights_response)
  end

  it "creates insights from article text" do
    expect { described_class.perform_now(article.id) }
      .to change { article.insights.count }.by(2)
  end

  it "sets insight attributes from LLM response" do
    described_class.perform_now(article.id)

    insight = article.insights.find_by(title: "Key Finding")
    expect(insight.body).to eq("The main takeaway.")
    expect(insight.status).to eq("complete")
  end

  it "skips articles without text" do
    article.update!(text: nil)

    expect { described_class.perform_now(article.id) }
      .not_to(change { Insight.count })
  end
end
