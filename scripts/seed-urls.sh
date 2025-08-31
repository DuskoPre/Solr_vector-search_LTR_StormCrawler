#!/bin/bash
set -e

SOLR_URL="http://localhost:8983/solr"
COLLECTION_NAME="hybrid_search"

echo "Seeding initial URLs and sample documents..."

# Add some sample documents with vectors
curl -X POST "$SOLR_URL/$COLLECTION_NAME/update" \
  -H "Content-Type: application/json" \
  -d '[
    {
      "id": "doc1",
      "url": "https://example.com/ai-overview",
      "title": "Introduction to Artificial Intelligence",
      "content": "Artificial intelligence (AI) is a branch of computer science that aims to create intelligent machines. Machine learning is a subset of AI that focuses on algorithms that can learn from data.",
      "content_vector": [0.1, 0.2, 0.3, 0.4, 0.5],
      "domain": "example.com",
      "crawl_date": "2025-08-31T00:00:00Z",
      "page_rank": 0.8,
      "content_length": 150
    },
    {
      "id": "doc2", 
      "url": "https://example.com/machine-learning",
      "title": "Machine Learning Fundamentals",
      "content": "Machine learning algorithms can be supervised, unsupervised, or reinforcement learning. Neural networks are a popular type of machine learning model inspired by biological neurons.",
      "content_vector": [0.2, 0.3, 0.1, 0.5, 0.4],
      "domain": "example.com",
      "crawl_date": "2025-08-30T00:00:00Z", 
      "page_rank": 0.7,
      "content_length": 180
    }
  ]'

# Commit changes
curl -X POST "$SOLR_URL/$COLLECTION_NAME/update" \
  -H "Content-Type: application/json" \
  -d '{"commit": {}}'

# Seed URLs for StormCrawler
redis-cli -h localhost -p 6379 LPUSH "crawl.queue" \
  "https://en.wikipedia.org/wiki/Information_retrieval" \
  "https://en.wikipedia.org/wiki/Machine_learning" \
  "https://en.wikipedia.org/wiki/Natural_language_processing"

echo "✅ URLs seeded successfully!"
