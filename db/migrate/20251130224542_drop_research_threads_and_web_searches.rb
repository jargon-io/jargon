# frozen_string_literal: true

class DropResearchThreadsAndWebSearches < ActiveRecord::Migration[8.1]
  def up
    drop_table :web_search_articles, if_exists: true
    drop_table :web_searches, if_exists: true
    drop_table :thread_articles, if_exists: true
    drop_table :research_threads, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
