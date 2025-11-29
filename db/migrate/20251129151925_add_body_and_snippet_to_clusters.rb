# frozen_string_literal: true

class AddBodyAndSnippetToClusters < ActiveRecord::Migration[8.1]
  def change
    add_column :clusters, :body, :text
    add_column :clusters, :snippet, :text
  end
end
