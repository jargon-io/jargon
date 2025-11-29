# Jargon

https://github.com/user-attachments/assets/78bd9150-f113-47b7-b682-b5d1647e49c6

## Dependencies

### crawl4ai

Fallback crawler when Exa is unavailable. Install via pip:

```bash
pip install crawl4ai
crawl4ai-setup  # Downloads browser dependencies
```

## TODO
* generate my own summaries and bold words (in snippets too)
  * get rid of "This article explores..." "This cluster contains..."
* have claude generate a better readme
* support white papers and articles that require navigating past abstract (eg: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5113355)
* simplify how queries are generated and retrieve in ResearchThreadJob
* semantic hooks - topic anchors for related content that is not necessarily directly related to a node, but related to a topic that is relevant
* filter captcha results and other scraper / search fails, eg: http://localhost:3000/articles/effect-of-ai-performance-perceived-risk-and-trust-on
* better UI for ask question -> fetch web results
* max-w for images in cards and on show pages
* make it easier to configure different LLM providers with env vars