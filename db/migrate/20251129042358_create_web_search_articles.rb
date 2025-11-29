class CreateWebSearchArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :web_search_articles do |t|
      t.references :web_search, null: false, foreign_key: true
      t.references :article, null: false, foreign_key: true

      t.timestamps
    end
  end
end
