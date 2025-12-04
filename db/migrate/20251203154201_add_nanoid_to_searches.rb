class AddNanoidToSearches < ActiveRecord::Migration[8.1]
  def change
    add_column :searches, :nanoid, :string, null: false, default: -> { "nanoid()" }
    add_index :searches, :nanoid, unique: true
    change_column_null :searches, :slug, true
  end
end
