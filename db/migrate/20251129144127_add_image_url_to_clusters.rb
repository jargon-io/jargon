# frozen_string_literal: true

class AddImageUrlToClusters < ActiveRecord::Migration[8.1]
  def change
    add_column :clusters, :image_url, :string
  end
end
