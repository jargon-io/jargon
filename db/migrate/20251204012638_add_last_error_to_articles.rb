# frozen_string_literal: true

class AddLastErrorToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :last_error, :text
  end
end
