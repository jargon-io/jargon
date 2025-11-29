# frozen_string_literal: true

class AddNotNullToClusterSlug < ActiveRecord::Migration[8.1]
  def change
    change_column_null :clusters, :slug, false
  end
end
