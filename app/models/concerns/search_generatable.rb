# frozen_string_literal: true

module SearchGeneratable
  extend ActiveSupport::Concern

  MAX_SEARCHES = 2

  QUERIES_PROMPT = <<~PROMPT
    Generate %<count>s research questions to explore this topic further.
    Questions should help develop a wholistic, intuitive, first-principles, or nuanced understanding
    of the subject, or create a connection to a new domain that may have useful insights.
    Do not simply drill down into specifics - point the reader in directions that will help them
    develop a more robust understanding or novel insights.
    Keep questions under 60 characters.
  PROMPT

  class_methods do
    attr_reader :search_context_method

    def search_context(method)
      @search_context_method = method
    end
  end

  included do
    has_many :searches, as: :source, dependent: :destroy
  end

  def generate_searches!(count: MAX_SEARCHES)
    return if searches.any?

    queries = generate_search_queries(count)
    queries.each { |query| searches.create!(query:) }
  end

  private

  def generate_search_queries(count)
    prompt = format(QUERIES_PROMPT, count:)
    context = search_context

    LLM.chat
       .with_instructions(prompt)
       .with_schema(SearchQueriesSchema)
       .ask(context)
       .content["queries"]
       .first(count)
  end

  def search_context
    method = self.class.search_context_method

    raise "No search_context defined for #{self.class}" unless method

    if method.is_a?(Proc)
      instance_exec(&method)
    else
      send(method)
    end
  end
end
