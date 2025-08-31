#!/bin/bash
set -e

SOLR_URL="http://localhost:8983/solr"
COLLECTION_NAME="hybrid_search"

echo "Creating collection with vector search support..."

# Create collection
curl -X POST "$SOLR_URL/admin/collections" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "CREATE",
    "name": "'$COLLECTION_NAME'",
    "numShards": 1,
    "replicationFactor": 1,
    "configSet": "_default"
  }'

echo "Collection created. Setting up schema..."

# Add vector field
curl -X POST "$SOLR_URL/$COLLECTION_NAME/schema" \
  -H "Content-Type: application/json" \
  -d '{
    "add-field": {
      "name": "content_vector",
      "type": "knn_vector",
      "vectorDimension": 384,
      "similarityFunction": "cosine",
      "knnAlgorithm": "hnsw"
    }
  }'

# Add other fields
curl -X POST "$SOLR_URL/$COLLECTION_NAME/schema" \
  -H "Content-Type: application/json" \
  -d '{
    "add-field": [
      {"name": "url", "type": "string", "indexed": true, "stored": true},
      {"name": "title", "type": "text_general", "indexed": true, "stored": true},
      {"name": "content", "type": "text_general", "indexed": true, "stored": true},
      {"name": "domain", "type": "string", "indexed": true, "stored": true},
      {"name": "crawl_date", "type": "pdate", "indexed": true, "stored": true},
      {"name": "page_rank", "type": "pfloat", "indexed": true, "stored": true},
      {"name": "content_length", "type": "plong", "indexed": true, "stored": true}
    ]
  }'

echo "✅ Collection setup complete!"
