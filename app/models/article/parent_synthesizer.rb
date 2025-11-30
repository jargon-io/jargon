# frozen_string_literal: true

class Article
  class ParentSynthesizer
    PROMPT = <<~PROMPT
      These are the same article from different sources. Generate:
      - A clean, canonical title (without source names like 'PubMed' or 'Nature')
      - A summary that states the key idea directly (not "this cluster is about...")
      - Use <strong> for 1-2 key terms
    PROMPT

    def initialize(children)
      @children = children
    end

    def synthesize
      context = @children.map { |a| format(a) }.join("\n\n---\n\n")

      response = LLM.chat
                    .with_schema(ClusterMetadataSchema)
                    .ask("#{PROMPT}\n\n#{context}")

      {
        title: response.content["name"],
        summary: response.content["summary"],
        image_url: @children.find { |a| a.image_url.present? }&.image_url
      }
    end

    private

    def format(article)
      <<~TEXT
        Title: #{article.title}
        Summary: #{article.summary}
        Author: #{article.author.presence || 'N/A'}
      TEXT
    end
  end
end
