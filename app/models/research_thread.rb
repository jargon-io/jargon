# frozen_string_literal: true

# Named ResearchThread to avoid conflict with Ruby's Thread class
class ResearchThread < ApplicationRecord
  self.table_name = "threads"

  belongs_to :insight

  enum :status, { pending: 0, researched: 1 }
end
