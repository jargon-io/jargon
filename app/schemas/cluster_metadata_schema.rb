# frozen_string_literal: true

class ClusterMetadataSchema < RubyLLM::Schema
  string :name, description: "Short, descriptive name for the cluster (3-6 words)"
  string :summary, description: "A concise but detailed summary of the common theme (100-300 characters)"
end
