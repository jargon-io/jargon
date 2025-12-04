# frozen_string_literal: true

class AddNanoidToInsights < ActiveRecord::Migration[8.1]
  def change
    add_column :insights, :nanoid, :string, null: false, default: -> { "nanoid()" }
    add_index :insights, :nanoid, unique: true
    change_column_null :insights, :slug, true
  end
end
