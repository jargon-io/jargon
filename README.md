<div align="center">
  <img width="400px" src="https://gist.githubusercontent.com/schoblaska/fd570fee9180de09e3c4fd57d26283b9/raw/8db84d442bcd12f4176b2918140df8656298907d/jargon_dark.png#gh-dark-mode-only" />
  <img width="400px" src="https://gist.githubusercontent.com/schoblaska/fd570fee9180de09e3c4fd57d26283b9/raw/8db84d442bcd12f4176b2918140df8656298907d/jargon_light.png#gh-light-mode-only" />
</div>

A personal research library that ingests articles, extracts insights, and surfaces connections across domains.

Drop in a URL and Jargon will scrape the content, summarize it with an LLM, extract key insights, and find related articles through semantic search. Or ask a question to pull relevant insights from your library, optionally augmented with web results.

## How It Works

1. **Ingest** - Paste a URL or ask a question. URLs get scraped (web pages, PDFs, YouTube transcripts). Questions search your library and the web.
2. **Summarize** - An LLM distills the core idea into a concise summary.
3. **Extract Insights** - Key findings are pulled out as standalone, linkable insights.
4. **Find Connections** - Embeddings enable semantic similarity search. Related articles cluster automatically.
5. **Research Threads** - Insights spawn research questions that trigger web searches for related articles.

## Features

### PDF Full-Text Extraction

Academic papers and PDFs are automatically downloaded and converted to text using `pdftotext`. Jargon follows "full text" and DOI links from abstracts.

<img src="https://gist.githubusercontent.com/schoblaska/fd570fee9180de09e3c4fd57d26283b9/raw/ec06277e2fd84db17fdcaa3d76a836505d596ee2/paper_dark.png#gh-dark-mode-only" />
<img src="https://gist.githubusercontent.com/schoblaska/fd570fee9180de09e3c4fd57d26283b9/raw/ec06277e2fd84db17fdcaa3d76a836505d596ee2/paper_light.png#gh-light-mode-only" />

### YouTube Transcripts

YouTube URLs are detected and transcripts are fetched directly from YouTube's API. Speakers are extracted from video titles when available.

<img src="https://gist.githubusercontent.com/schoblaska/fd570fee9180de09e3c4fd57d26283b9/raw/242f599e4307f36da9a2f8a3537658315e13b64b/youtube_dark.png#gh-dark-mode-only" />
<img src="https://gist.githubusercontent.com/schoblaska/fd570fee9180de09e3c4fd57d26283b9/raw/242f599e4307f36da9a2f8a3537658315e13b64b/youtube_light.png#gh-light-mode-only" />

### Insight Extraction

Key findings are extracted as standalone insights with titles, explanations, and source snippets. Insights are independently searchable and linkable.

<img src="https://gist.githubusercontent.com/schoblaska/fd570fee9180de09e3c4fd57d26283b9/raw/731970caa6ed87082fbe89eaa88fd78b41a06a18/insight_dark.png#gh-dark-mode-only" />
<img src="https://gist.githubusercontent.com/schoblaska/fd570fee9180de09e3c4fd57d26283b9/raw/731970caa6ed87082fbe89eaa88fd78b41a06a18/insight_light.png#gh-light-mode-only" />

### Semantic Embeddings

Articles and insights are embedded using OpenAI's text-embedding-3-small model. Embeddings power similarity search and automatic clustering.

### Automatic Clustering

Similar articles (syndicated content, republished pieces) are automatically grouped using vector similarity and title matching. Similar insights cluster into themes.

### Research Threads

Each insight can spawn research threads—questions that trigger web searches via Exa to find related articles. Discovered articles are automatically ingested and indexed.

<img src="https://gist.githubusercontent.com/schoblaska/fd570fee9180de09e3c4fd57d26283b9/raw/e85846f6b623c1bdbd8db09931dacf9c862b83c8/threads_dark.png#gh-dark-mode-only" />
<img src="https://gist.githubusercontent.com/schoblaska/fd570fee9180de09e3c4fd57d26283b9/raw/e85846f6b623c1bdbd8db09931dacf9c862b83c8/threads_light.png#gh-light-mode-only" />

### Library Search

Ask a question or enter a topic to search your library. Jargon finds relevant insights using semantic similarity and displays them alongside the source articles.

### Web Search

Augment library results with fresh content from the web. Results are fetched via Exa's neural search and automatically ingested into your library.

## Tech Stack

- **[Rails](https://rubyonrails.org/)** and **[Hotwire](https://hotwired.dev/)**
- **[Falcon](https://github.com/socketry/falcon)** - Async Ruby application server with fiber-based concurrency
- **[async-job](https://github.com/socketry/async-job)** - Background job processing without a separate worker process
- **[RubyLLM](https://github.com/contextco/ruby_llm)** - Unified interface to OpenAI, Anthropic, Gemini, and OpenRouter
- **[ruby_llm-schema](https://github.com/schoblaska/ruby_llm-schema)** - Structured JSON output from LLMs via schema definitions
- **[pgvector](https://github.com/pgvector/pgvector)** - Vector similarity search in PostgreSQL
- **[Exa](https://exa.ai)** - Neural search API for finding related content
- **[crawl4ai](https://github.com/unclecode/crawl4ai)** - Fallback web scraper with browser rendering
- **[pdftotext](https://manpages.debian.org/testing/poppler-utils/pdftotext.1.en.html)** - Text extractor for PDF content

## Configuration

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

### LLM Providers

Set API keys for the providers you want to use. RubyLLM supports OpenRouter, OpenAI, Anthropic, and Google Gemini:

```bash
OPENROUTER_API_KEY=your-key    # OpenRouter (default, proxies all providers)
OPENAI_API_KEY=your-key        # Direct OpenAI access
ANTHROPIC_API_KEY=your-key     # Direct Anthropic access
GEMINI_API_KEY=your-key        # Direct Google Gemini access
```

### Model and Provider Selection

Override default models and providers via environment variables:

```bash
LLM_MODEL=google/gemini-2.5-flash              # Chat model (default)
LLM_PROVIDER=openrouter                        # Chat provider (default)
EMBEDDING_MODEL=openai/text-embedding-3-small  # Embedding model (default)
EMBEDDING_PROVIDER=openrouter                  # Embedding provider (default)
```

Provider must match the API key you're using. OpenRouter model names use `provider/model` format.

### Rails Master Key

Set `SECRET_KEY_BASE` instead of using `config/master.key`:

```bash
SECRET_KEY_BASE=secret-key-base
```

## Dependencies

### crawl4ai

Fallback crawler when Exa is unavailable. Install via pip:

```bash
pip install crawl4ai
crawl4ai-setup  # Downloads browser dependencies
```

### pdftotext

Used for extracting text from PDF documents (academic papers, etc.). Install via poppler:

```bash
# macOS
brew install poppler

# Ubuntu/Debian
apt-get install poppler-utils
```

## Docker Deployment

Run Jargon with Docker Compose using the published image from GitHub Container Registry.

Create a `docker-compose.yml`:

```yaml
services:
  jargon:
    image: ghcr.io/schoblaska/jargon:latest
    ports:
      - "3000:80"
    env_file: .env
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/jargon
      REDIS_URL: redis://redis:6379/0
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started

  db:
    image: pgvector/pgvector:pg17
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: jargon
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

Create a `.env` file with your secrets:

```bash
SECRET_KEY_BASE=secret-key-base
OPENROUTER_API_KEY=your-openrouter-key
EXA_API_KEY=your-exa-key
```

Start the stack:

```bash
docker compose up -d
```

The app will be available at http://localhost:3000.

## TODO
* replace Exa with Brave search and use crawl4ai to ingest
  * do parallel searches across multiple LLM-generated queries?
* refactor IngestArticleJob
* define schemas inline where they're used
* export markdown to clipboard
* full text search