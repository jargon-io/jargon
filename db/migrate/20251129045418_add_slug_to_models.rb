# frozen_string_literal: true

class AddSlugToModels < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :slug, :string
    add_column :insights, :slug, :string
    add_column :threads, :slug, :string

    add_index :articles, :slug, unique: true
    add_index :insights, :slug, unique: true
    add_index :threads, :slug, unique: true

    remove_column :articles, :nanoid, :string
    remove_column :insights, :nanoid, :string
    remove_column :threads, :nanoid, :string
  end
end
