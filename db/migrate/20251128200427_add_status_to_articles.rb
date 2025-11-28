# frozen_string_literal: true

class AddStatusToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :status, :integer, default: 0, null: false
    add_index :articles, :url, unique: true
    change_column_null :articles, :text, true
    change_column_null :articles, :title, true
  end
end
