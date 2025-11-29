class CreateWebSearches < ActiveRecord::Migration[8.1]
  def change
    create_table :web_searches do |t|
      t.string :query, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end
  end
end
