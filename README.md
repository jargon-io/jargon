# Jargon

https://github.com/user-attachments/assets/78bd9150-f113-47b7-b682-b5d1647e49c6

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

Set `RAILS_MASTER_KEY` instead of using `config/master.key`:

```bash
RAILS_MASTER_KEY=your-master-key
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
RAILS_MASTER_KEY=your-master-key
OPENROUTER_API_KEY=your-openrouter-key
EXA_API_KEY=your-exa-key
```

Start the stack:

```bash
docker compose up -d
```

The app will be available at http://localhost:3000.

## TODO
* better responsive styles
* better root page ui (all nodes, no header, search box is in content area instead of floating header, explainer content?)
* have claude generate a better readme
* use library as RAG and have search box return results but also synthesize and respond with LLM answer
* export markdown to clipboard