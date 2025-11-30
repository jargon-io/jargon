# frozen_string_literal: true

class Insight
  class ParentSynthesizer
    class Schema < RubyLLM::Schema
      string :title, description: "The canonical insight as a concise title (5-10 words)"
      string :body, description: "Distilled insight (2-4 sentences). Use <strong> for emphasis. State directly."
      string :snippet, description: "Synthesized quote (1-2 sentences). May use <strong> and ellipses."
    end

    PROMPT = <<~PROMPT
      These are variations of the same insight from different sources. Synthesize into ONE canonical insight:
      - Captures the core idea directly (not "this cluster is about...")
      - Incorporates nuance and detail from all variations
      - Use <strong> for 1-2 key terms
      - Snippet may use ellipses (...) to tighten
    PROMPT

    def initialize(children)
      @children = children
    end

    def synthesize
      context = @children.map { |i| format(i) }.join("\n\n---\n\n")

      response = LLM.chat
                    .with_schema(Schema)
                    .ask("#{PROMPT}\n\n#{context}")

      {
        title: response.content["title"],
        body: response.content["body"],
        snippet: response.content["snippet"]
      }
    end

    private

    def format(insight)
      <<~TEXT
        Title: #{insight.title}
        Body: #{insight.body}
        Snippet: #{insight.snippet}
      TEXT
    end
  end
end
