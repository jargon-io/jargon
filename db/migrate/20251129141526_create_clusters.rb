# frozen_string_literal: true

class CreateClusters < ActiveRecord::Migration[8.1]
  def change
    create_table :clusters do |t|
      t.string :clusterable_type, null: false
      t.string :name
      t.string :slug
      t.text :summary
      t.integer :status, null: false, default: 0
      t.column :embedding, :vector, limit: 1536
      t.timestamps
    end

    add_index :clusters, :slug, unique: true
    add_index :clusters, :clusterable_type

    create_table :cluster_memberships do |t|
      t.references :cluster, null: false, foreign_key: true
      t.references :clusterable, polymorphic: true, null: false
      t.float :distance_to_centroid
      t.timestamps
    end

    add_index :cluster_memberships, [:clusterable_type, :clusterable_id], unique: true, name: "idx_cluster_memberships_uniqueness"
  end
end
