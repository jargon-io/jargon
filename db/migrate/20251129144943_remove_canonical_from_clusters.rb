# frozen_string_literal: true

class RemoveCanonicalFromClusters < ActiveRecord::Migration[8.1]
  def change
    remove_reference :clusters, :canonical, polymorphic: true
  end
end
