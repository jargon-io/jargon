# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchJob do
  describe "#claim_job?" do
    it "claims a pending search and transitions to searching" do
      search = create(:search, status: :pending)

      job = described_class.new
      result = job.send(:claim_job?, search)

      expect(result).to be true
      expect(search.reload.status).to eq("searching")
    end

    it "claims an already searching search (idempotent retry)" do
      search = create(:search, status: :searching)

      job = described_class.new
      result = job.send(:claim_job?, search)

      expect(result).to be true
      expect(search.reload.status).to eq("searching")
    end

    it "rejects a complete search" do
      search = create(:search, status: :complete)

      job = described_class.new
      result = job.send(:claim_job?, search)

      expect(result).to be false
      expect(search.reload.status).to eq("complete")
    end

    it "rejects a failed search" do
      search = create(:search, status: :failed)

      job = described_class.new
      result = job.send(:claim_job?, search)

      expect(result).to be false
      expect(search.reload.status).to eq("failed")
    end

    it "handles race condition - only one job wins" do
      search = create(:search, status: :pending)

      # Simulate another process claiming the job first
      Search.where(id: search.id).update_all(status: :complete)

      job = described_class.new
      result = job.send(:claim_job?, search)

      expect(result).to be false
    end
  end
end
