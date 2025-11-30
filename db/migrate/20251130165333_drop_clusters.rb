# frozen_string_literal: true

class DropClusters < ActiveRecord::Migration[8.1]
  def up
    drop_table :cluster_memberships
    drop_table :clusters
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
