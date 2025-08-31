#!/bin/bash
set -e

SOLR_URL="http://localhost:8983/solr"
COLLECTION_NAME="hybrid_search"
EMBEDDING_URL="http://localhost:8080"

echo "🔍 Real-World Query Examples with all-MiniLM-L6-v2"
echo "=================================================="

# Test queries with real semantic meaning
QUERIES=("machine learning algorithms" "neural network architectures" "information retrieval systems" "natural language processing")

for QUERY in "${QUERIES[@]}"; do
    echo ""
    echo "🎯 Query: '$QUERY'"
    echo "----------------------------------------"
    
    # 1. BM25 Search
    echo "1️⃣ BM25 Results:"
    curl -s "$SOLR_URL/$COLLECTION_NAME/select" \
        -d "q=${QUERY}&defType=edismax&qf=title^2 content&rows=3&fl=id,title,score" | \
        jq -r '.response.docs[] | "  📄 \(.title[0:60])... | Score: \(.score | tonumber | . * 100 | round / 100)"'
    
    # 2. Vector Search with real all-MiniLM-L6-v2 embedding
    echo "2️⃣ Vector Search (all-MiniLM-L6-v2):"
    
    # Generate real embedding for query
    QUERY_VECTOR=$(curl -s "$EMBEDDING_URL/encode" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"${QUERY}\"}" | jq -r '.embedding | @json')
    
    if [[ "$QUERY_VECTOR" != "null" && -n "$QUERY_VECTOR" ]]; then
        curl -s "$SOLR_URL/$COLLECTION_NAME/select" \
            -d "q={!knn f=content_vector topK=3}${QUERY_VECTOR}&fl=id,title,score" | \
            jq -r '.response.docs[] | "  🧠 \(.title[0:60])... | Similarity: \(.score | tonumber | . * 100 | round / 100)"'
    else
        echo "  ❌ Failed to generate embedding for query"
    fi
    
    # 3. Hybrid + LTR (best results)
    echo "3️⃣ Hybrid + LTR Re-ranking:"
    curl -s "$SOLR_URL/$COLLECTION_NAME/select" \
        -d "q=${QUERY}&defType=edismax&qf=title^2 content&rq={!ltr model=hybrid_ranker reRankDocs=10}&rows=3&fl=id,title,score" | \
        jq -r '.response.docs[] | "  🎯 \(.title[0:60])... | Final Score: \(.score | tonumber | . * 100 | round / 100)"'
    
    echo ""
done

echo "🔬 Feature Analysis Example:"
echo "============================="

# Show LTR features for a specific query
ANALYSIS_QUERY="machine learning"
echo "Analyzing features for: '$ANALYSIS_QUERY'"

curl -s "$SOLR_URL/$COLLECTION_NAME/select" \
    -d "q=${ANALYSIS_QUERY}&rq={!ltr model=hybrid_ranker reRankDocs=5}&rows=1&fl=id,title,[features]" | \
    jq -r '.response.docs[0] | "
📋 Document: \(.title)
🔍 Feature Scores:
\(."[features]" | fromjson | to_entries[] | "   \(.key): \(.value)")
"'
