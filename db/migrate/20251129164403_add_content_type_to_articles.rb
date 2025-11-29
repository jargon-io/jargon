# frozen_string_literal: true

class AddContentTypeToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :content_type, :integer, default: 0, null: false
  end
end
