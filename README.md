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

## TODO
* publish docker image on GH and add compose recipe to readme
* better responsive styles
* better root page ui (all nodes, no header, search box is in content area instead of floating header, explainer content?)
* have claude generate a better readme
* use library as RAG and have search box return results but also synthesize and respond with LLM answer
* export markdown to clipboard