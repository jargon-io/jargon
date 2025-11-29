# frozen_string_literal: true

class CreateTopics < ActiveRecord::Migration[8.1]
  def change
    create_table :topics do |t|
      t.references :topicable, polymorphic: true, null: false
      t.string :phrase, null: false
      t.vector :embedding, limit: 1536
      t.timestamps
    end

    add_index :topics, %i[topicable_type topicable_id]
  end
end
