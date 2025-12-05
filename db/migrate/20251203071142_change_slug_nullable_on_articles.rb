# frozen_string_literal: true

class ChangeSlugNullableOnArticles < ActiveRecord::Migration[8.1]
  def change
    change_column_null :articles, :slug, true
  end
end
