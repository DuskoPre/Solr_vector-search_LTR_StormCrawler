#!/bin/bash
set -e

SOLR_URL="http://localhost:8983/solr"
COLLECTION_NAME="hybrid_search"

echo "Seeding real Wikipedia URLs for StormCrawler to scrape..."

# StormCrawler will scrape these URLs and automatically generate embeddings
# No manual documents needed - everything comes from real web scraping

# Seed real Wikipedia URLs for StormCrawler  
redis-cli -h localhost -p 6379 LPUSH "crawl.queue" \
  "https://en.wikipedia.org/wiki/Information_retrieval" \
  "https://en.wikipedia.org/wiki/Machine_learning" \
  "https://en.wikipedia.org/wiki/Natural_language_processing"

echo "✅ Real URLs seeded! StormCrawler will:"
echo "   1. Scrape content from Wikipedia pages"
echo "   2. Extract text using Tika"
echo "   3. Generate vectors using all-MiniLM-L6-v2"
echo "   4. Index everything into Solr automatically"

echo "✅ URLs seeded successfully!"
