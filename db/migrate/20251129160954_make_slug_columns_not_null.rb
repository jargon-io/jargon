# frozen_string_literal: true

class MakeSlugColumnsNotNull < ActiveRecord::Migration[8.0]
  def up
    execute "TRUNCATE articles, insights, threads CASCADE"

    change_column_null :articles, :slug, false
    change_column_null :insights, :slug, false
    change_column_null :threads, :slug, false
  end

  def down
    change_column_null :articles, :slug, true
    change_column_null :insights, :slug, true
    change_column_null :threads, :slug, true
  end
end
