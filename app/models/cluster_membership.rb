# frozen_string_literal: true

class ClusterMembership < ApplicationRecord
  belongs_to :cluster
  belongs_to :clusterable, polymorphic: true
end
