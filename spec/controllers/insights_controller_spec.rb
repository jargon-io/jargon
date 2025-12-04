# frozen_string_literal: true

require "rails_helper"

RSpec.describe InsightsController do
  describe "GET #show" do
    it "loads insight page without N+1 queries" do
      article = create(:article)
      insight = create(:insight, article:)
      create_list(:search, 3, source: insight)

      get :show, params: { id: insight.slug }

      expect(response).to have_http_status(:ok)
    end

    context "with parent insight and similar items" do
      it "loads page without wasteful eager loading" do
        # Create parent insights (roots) that will appear in similar items
        3.times { create(:insight, :parent) }

        article = create(:article)
        parent_insight = create(:insight, :parent, article:)

        get :show, params: { id: parent_insight.slug }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
