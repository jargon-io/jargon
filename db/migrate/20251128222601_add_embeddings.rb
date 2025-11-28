# frozen_string_literal: true

class AddEmbeddings < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"

    add_column :articles, :embedding, :vector, limit: 1536
    add_column :insights, :embedding, :vector, limit: 1536
  end
end
