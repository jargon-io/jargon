# frozen_string_literal: true

class AddOriginToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :origin, :integer, default: 0, null: false
    add_index :articles, :origin

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE articles
          SET origin = 1
          WHERE id IN (SELECT DISTINCT article_id FROM search_articles)
        SQL
      end
    end
  end
end
