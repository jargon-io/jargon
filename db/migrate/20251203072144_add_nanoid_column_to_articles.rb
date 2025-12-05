# frozen_string_literal: true

class AddNanoidColumnToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :nanoid, :string, null: false, default: -> { "nanoid()" }
    add_index :articles, :nanoid, unique: true
  end
end
