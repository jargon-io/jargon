# frozen_string_literal: true

class CreateSearchArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :search_articles do |t|
      t.references :search, null: false, foreign_key: true
      t.references :article, null: false, foreign_key: true

      t.timestamps
    end

    add_index :search_articles, %i[search_id article_id], unique: true
  end
end
