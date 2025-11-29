# frozen_string_literal: true

class AddSubjectToThreads < ActiveRecord::Migration[8.1]
  def change
    add_reference :threads, :subject, polymorphic: true

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE threads
          SET subject_type = 'Insight', subject_id = insight_id
          WHERE insight_id IS NOT NULL
        SQL
      end
    end

    remove_reference :threads, :insight, foreign_key: true
    remove_reference :threads, :article, foreign_key: true
  end
end
