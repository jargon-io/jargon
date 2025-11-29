# frozen_string_literal: true

class EnhanceResearchThreads < ActiveRecord::Migration[8.1]
  def change
    # Add fields to threads table
    add_column :threads, :nanoid, :string, null: false, default: -> { "nanoid()" }
    add_column :threads, :article_id, :bigint
    add_index :threads, :nanoid, unique: true
    add_foreign_key :threads, :articles

    # Create join table for thread -> discovered articles
    create_table :thread_articles do |t|
      t.references :research_thread, null: false, foreign_key: { to_table: :threads }
      t.references :article, null: false, foreign_key: true
      t.text :relevance_note
      t.timestamps
    end

    add_index :thread_articles, %i[research_thread_id article_id], unique: true
  end
end
