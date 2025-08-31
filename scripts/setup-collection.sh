#!/bin/bash
set -e

SOLR_URL="http://localhost:8983/solr"
COLLECTION_NAME="hybrid_search"

echo "🔧 Creating collection with fixed vector search support..."

# Wait for Solr to be fully ready
echo "⏳ Waiting for Solr to be ready..."
while ! curl -s "$SOLR_URL/admin/ping" | grep -q '"status":"OK"'; do
    echo "   Waiting for Solr..."
    sleep 5
done

# Delete collection if it exists (for clean setup)
echo "🧹 Cleaning existing collection if present..."
curl -s -X POST "$SOLR_URL/admin/collections" \
  -d "action=DELETE&name=$COLLECTION_NAME" || echo "Collection didn't exist"

sleep 2

# Create collection with proper configuration
echo "📋 Creating collection: $COLLECTION_NAME"
curl -X POST "$SOLR_URL/admin/collections" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "action=CREATE&name=$COLLECTION_NAME&numShards=1&replicationFactor=1&configSet=_default"

# Wait for collection to be ready
echo "⏳ Waiting for collection to be ready..."
sleep 10

# Check collection status
curl -s "$SOLR_URL/$COLLECTION_NAME/admin/ping" | grep -q '"status":"OK"' || {
    echo "❌ Collection not ready, retrying..."
    sleep 10
}

echo "✅ Collection created successfully!"

# Add vector field with proper Solr 9.x syntax
echo "🧠 Adding vector field (384 dimensions, all-MiniLM-L6-v2)..."
curl -X POST "$SOLR_URL/$COLLECTION_NAME/schema" \
  -H "Content-Type: application/json" \
  -d '{
    "add-field-type": {
      "name": "knn_vector",
      "class": "solr.DenseVectorField",
      "vectorDimension": 384,
      "similarityFunction": "cosine",
      "knnAlgorithm": "hnsw"
    }
  }' || echo "Field type may already exist"

sleep 2

curl -X POST "$SOLR_URL/$COLLECTION_NAME/schema" \
  -H "Content-Type: application/json" \
  -d '{
    "add-field": {
      "name": "content_vector",
      "type": "knn_vector",
      "indexed": true,
      "stored": true
    }
  }' || echo "Vector field may already exist"

# Add other required fields
echo "📝 Adding content fields..."
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
  }' || echo "Some fields may already exist"

echo "🔍 Verifying schema setup..."
curl -s "$SOLR_URL/$COLLECTION_NAME/schema/fields/content_vector" | jq '.field' || {
    echo "❌ Vector field verification failed"
    echo "📋 Manual fix needed - check Solr logs"
}

echo "✅ Collection schema setup complete!"
echo ""
echo "📊 Collection info:"
curl -s "$SOLR_URL/$COLLECTION_NAME/schema/fields" | jq -r '.fields[] | select(.name | startswith("content")) | "\(.name): \(.type)"'
