# frozen_string_literal: true

class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.string :title, null: false
      t.string :url, null: false
      t.string :author
      t.datetime :published_at
      t.text :summary
      t.text :text, null: false
      t.string :image_url
      t.timestamps
    end
  end
end
