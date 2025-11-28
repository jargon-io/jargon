# frozen_string_literal: true

class CreateInsightsAndThreads < ActiveRecord::Migration[8.1]
  def change
    create_table :insights do |t|
      t.references :article, null: false, foreign_key: true
      t.string :nanoid, null: false, default: -> { "nanoid()" }
      t.string :title
      t.text :body
      t.text :snippet
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :insights, :nanoid, unique: true

    create_table :threads do |t|
      t.references :insight, null: false, foreign_key: true
      t.text :query, null: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end
  end
end
