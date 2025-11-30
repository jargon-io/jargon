# frozen_string_literal: true

class AddParentToArticlesAndInsights < ActiveRecord::Migration[8.1]
  def change
    add_reference :articles, :parent, foreign_key: { to_table: :articles }, index: true
    add_reference :insights, :parent, foreign_key: { to_table: :insights }, index: true
    change_column_null :articles, :url, true
  end
end
