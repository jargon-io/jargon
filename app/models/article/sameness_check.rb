# frozen_string_literal: true

class Article
  class SamenessCheck
    TITLE_SIMILARITY_THRESHOLD = 0.7

    class Schema < RubyLLM::Schema
      boolean :same_article,
              description: "True if these are the SAME underlying work (same paper, essay, news story) " \
                           "possibly from different sources. False if merely similar topics."
      string :reason, description: "Brief explanation of why these are or aren't the same article"
    end

    def initialize(article, candidate, embedding_distance:)
      @article = article
      @candidate = candidate
      @embedding_distance = embedding_distance
    end

    def same?
      title_similar? && llm_confirms?
    end

    private

    def title_similar?
      similarity = title_similarity(@article.title, @candidate.title)
      threshold = @embedding_distance < 0.05 ? 0.5 : TITLE_SIMILARITY_THRESHOLD

      similarity >= threshold
    end

    def llm_confirms?
      prompt = <<~PROMPT
        Are these two articles about the SAME specific content (same paper, same news story, same essay)?
        Not just the same topic - they must be the same underlying work, possibly from different sources.

        Article 1:
        - Title: #{@article.title}
        - Author: #{@article.author.presence || 'Unknown'}
        - Summary: #{@article.summary.to_s.truncate(500)}

        Article 2:
        - Title: #{@candidate.title}
        - Author: #{@candidate.author.presence || 'Unknown'}
        - Summary: #{@candidate.summary.to_s.truncate(500)}
      PROMPT

      response = LLM.chat.with_schema(Schema).ask(prompt)
      response.content["same_article"] == true
    rescue StandardError => e
      Rails.logger.error("LLM article comparison failed: #{e.message}")
      false
    end

    def title_similarity(a, b)
      return 0.0 if a.blank? || b.blank?

      a_normalized = a.downcase.gsub(/[^\w\s]/, "")
      b_normalized = b.downcase.gsub(/[^\w\s]/, "")

      return 1.0 if a_normalized == b_normalized

      longer = [a_normalized.length, b_normalized.length].max.to_f
      return 0.0 if longer.zero?

      1.0 - (levenshtein_distance(a_normalized, b_normalized) / longer)
    end

    def levenshtein_distance(s, t)
      m = s.length
      n = t.length

      return n if m.zero?
      return m if n.zero?

      d = Array.new(m + 1) { |i| i }

      (1..n).each do |j|
        x = Array.new(m + 1)
        x[0] = j

        (1..m).each do |i|
          cost = s[i - 1] == t[j - 1] ? 0 : 1
          x[i] = [x[i - 1] + 1, d[i] + 1, d[i - 1] + cost].min
        end

        d = x
      end

      d[m]
    end
  end
end
