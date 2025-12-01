# frozen_string_literal: true

class CreateSearches < ActiveRecord::Migration[8.1]
  def change
    create_table :searches do |t|
      t.string :slug, null: false
      t.text :query, null: false
      t.text :search_query
      t.vector :search_query_embedding, limit: 1536
      t.text :summary
      t.text :snippet
      t.vector :embedding, limit: 1536
      t.integer :status, default: 0, null: false
      t.references :source, polymorphic: true, index: true

      t.timestamps
    end

    add_index :searches, :slug, unique: true
    add_index :searches, :status
  end
end
