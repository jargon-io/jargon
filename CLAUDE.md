# Jargon

## Rails Architecture

### Rich Domain Models
Models are the application API. Controllers access them directly—no service layers, interactors, or repositories between them. Business logic lives in models, not procedural wrappers.

```ruby
# Yes
recording.incinerate

# No
Recording::IncinerationService.execute(recording)
```

### Concerns as Traits
Concerns organize related behavior within models. Each concern represents a genuine trait the model possesses—"acts as" or "has behavior" semantics. Not arbitrary buckets for splitting large files.

Good concerns:
- Capture a unified domain concept
- Hide complex subsystems behind clean APIs
- Read like natural language
- Provide declarative DSL for configuration

```ruby
class Article < ApplicationRecord
  include Parentable    # "acts as parentable"
  include Embeddable    # "has embeddings"
  include Sluggable     # "has a slug"

  embeddable :summary   # Clear what this configures
  slug -> { title }     # Declarative, self-documenting
end
```

### Concern Anti-pattern: Abstract Methods
Concerns should not require models to implement abstract methods. This is lazy API design—the model author has no idea what the method is for or what contract it fulfills.

```ruby
# Bad: model must implement mystery methods
module Parentable
  def similarity_threshold
    raise NotImplementedError
  end
end

class Article < ApplicationRecord
  include Parentable

  def similarity_threshold  # What is this? Why 0.3?
    0.3
  end
end
```

Instead, concerns should provide clear DSL-style class methods:

```ruby
# Good: declarative configuration with clear intent
module Parentable
  class_methods do
    def parent_matching(threshold:, &block)
      @parent_threshold = threshold
      @similar_enough_check = block
    end
  end
end

class Article < ApplicationRecord
  include Parentable

  parent_matching threshold: 0.3 do |candidate|
    same_content?(candidate)
  end
end
```

### Model-Specific Classes
When a concern needs model-specific behavior, or when a model has a distinct responsibility that deserves its own object, use namespaced classes under the model directory.

```
app/models/
  article.rb
  article/
    parent_synthesizer.rb   # Synthesizes metadata for parent articles
    sameness_check.rb       # Determines if two articles are the same content
  insight.rb
  insight/
    parent_synthesizer.rb   # Synthesizes metadata for parent insights
```

These classes encapsulate a single responsibility with a clear API:

```ruby
# In Article - delegates to collaborator via DSL block
parent_matching threshold: 0.3 do |candidate, distance|
  SamenessCheck.new(self, candidate, embedding_distance: distance).same?
end

# Article::SamenessCheck encapsulates the algorithm
class Article::SamenessCheck
  def initialize(article, candidate, embedding_distance:)
    @article = article
    @candidate = candidate
    @embedding_distance = embedding_distance
  end

  def same?
    title_similar? && llm_confirms?
  end

  private
  # ... implementation details hidden
end
```

### Persistence and Domain Logic Together
Active Record blends persistence with domain logic intentionally. Don't fight it. Query scopes, callbacks, and validations belong in models. Wrap complex operations in private methods or small collaborator classes.

### Manage Complexity Through Organization
Prevent "fat models" with:
- **Concerns**: Group related functionality by domain concept
- **Namespaced classes**: Extract complex algorithms while keeping the public API on the model
- **Query scopes**: Centralize query logic, compose with associations

## Testing

### RSpec Patterns
- One behavior per test
- AAA structure (Arrange-Act-Assert) with whitespace
- Minimal factories with traits
- Flat structure, max 2 nesting levels
- `stub_llm` for LLM calls in tests
