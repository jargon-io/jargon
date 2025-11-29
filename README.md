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
* fix search controller ref to embedding service
* have claude generate a better readme
* support white papers and articles that require navigating past abstract (eg: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5113355)
* semantic hooks - topic anchors for related content that is not necessarily directly related to a node, but related to a topic that is relevant
* better UI for ask question -> fetch web results
* make it easier to configure different LLM providers with env vars
* publish docker image on GH and add compose recipe to readme
* better responsive styles
* specs
* page titles
* better root page ui (all nodes, no header, search box is in content area instead of floating header)
* internal links in summaries