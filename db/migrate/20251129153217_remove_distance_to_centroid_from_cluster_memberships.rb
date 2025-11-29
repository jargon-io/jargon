class RemoveDistanceToCentroidFromClusterMemberships < ActiveRecord::Migration[8.1]
  def change
    remove_column :cluster_memberships, :distance_to_centroid, :float
  end
end
