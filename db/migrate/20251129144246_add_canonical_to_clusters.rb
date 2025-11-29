# frozen_string_literal: true

class AddCanonicalToClusters < ActiveRecord::Migration[8.1]
  def change
    add_reference :clusters, :canonical, polymorphic: true, null: true
  end
end
