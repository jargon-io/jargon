# frozen_string_literal: true

class DropTopics < ActiveRecord::Migration[8.1]
  def up
    drop_table :topics
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
