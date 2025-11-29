# frozen_string_literal: true

module ResearchThreadGeneratable
  extend ActiveSupport::Concern

  MAX_RESEARCH_THREADS = 3

  QUERIES_PROMPT = <<~PROMPT
    Generate %<count>s research questions to explore this topic further.
    Questions should be specific, actionable, and lead to discovering related content.
  PROMPT

  included do
    has_many :research_threads, as: :subject, dependent: :destroy
  end

  def generate_research_threads!(count: MAX_RESEARCH_THREADS)
    return if research_threads.any?

    queries = generate_research_queries(count)
    queries.each { |query| research_threads.create!(query:) }
  end

  private

  def generate_research_queries(count)
    prompt = format(QUERIES_PROMPT, count:)
    context = research_thread_context

    RubyLLM.chat
           .with_instructions(prompt)
           .with_schema(ResearchQueriesSchema)
           .ask(context)
           .content["queries"]
           .first(count)
  end

  def research_thread_context
    raise NotImplementedError, "#{self.class} must implement #research_thread_context"
  end
end
