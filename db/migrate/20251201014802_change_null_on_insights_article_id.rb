# frozen_string_literal: true

class ChangeNullOnInsightsArticleId < ActiveRecord::Migration[8.1]
  def change
    change_column_null :insights, :article_id, true
  end
end
