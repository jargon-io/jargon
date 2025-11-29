# frozen_string_literal: true

class ClusterMetadataSchema < RubyLLM::Schema
  string :name, description: "Short, descriptive name for the cluster (3-6 words)"
  string :summary, description: "100-300 char summary. Use <strong> for 1-2 key terms. State the theme directly."
end
