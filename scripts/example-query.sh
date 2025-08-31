#!/bin/bash
set -e

SOLR_URL="http://localhost:8983/solr"
COLLECTION_NAME="hybrid_search"
QUERY="machine learning algorithms"

echo "🔍 Running hybrid search query: '$QUERY'"
echo ""

# Step 1: Regular BM25 search
echo "1️⃣ BM25 Search Results:"
curl -s "$SOLR_URL/$COLLECTION_NAME/select" \
  -d "q=${QUERY}&defType=edismax&qf=title^2 content&rows=5&fl=id,title,score" | \
  jq -r '.response.docs[] | "ID: \(.id) | Score: \(.score) | Title: \(.title)"'

echo ""

# Step 2: Vector search with real all-MiniLM-L6-v2 embeddings
echo "2️⃣ Vector Search Results:"
# Get real vector embedding for the query
QUERY_VECTOR=$(curl -s "http://localhost:8080/encode" \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"${QUERY}\"}" | jq -r '.embedding | @json')

curl -s "$SOLR_URL/$COLLECTION_NAME/select" \
  -d "q={!knn f=content_vector topK=5}${QUERY_VECTOR}&fl=id,title,score" | \
  jq -r '.response.docs[] | "ID: \(.id) | Score: \(.score) | Title: \(.title)"'

echo ""

# Step 3: Hybrid search with LTR re-ranking
echo "3️⃣ Hybrid Search + LTR Re-ranking:"
curl -s "$SOLR_URL/$COLLECTION_NAME/select" \
  -d "q=${QUERY}&defType=edismax&qf=title^2 content&rq={!ltr model=hybrid_ranker reRankDocs=10}&rows=5&fl=id,title,score,[features]" | \
  jq -r '.response.docs[] | "ID: \(.id) | Score: \(.score) | Title: \(.title)"'

echo ""
echo "✅ Query examples complete!"
