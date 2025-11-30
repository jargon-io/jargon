# frozen_string_literal: true

class ArticleSamenessSchema < RubyLLM::Schema
  boolean :same_article,
          description: "True if these are the SAME underlying work (same paper, essay, news story) " \
                       "possibly from different sources. False if merely similar topics."
  string :reason, description: "Brief explanation of why these are or aren't the same article"
end
