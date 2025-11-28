# frozen_string_literal: true

class AddNanoid < ActiveRecord::Migration[8.1]
  def up
    execute Rails.root.join("db/nanoid.sql").read
  end

  def down
    execute "DROP FUNCTION nanoid();"
  end
end
