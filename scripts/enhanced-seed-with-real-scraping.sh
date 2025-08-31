#!/bin/bash
set -e

SOLR_URL="http://localhost:8983/solr"
COLLECTION_NAME="hybrid_search"
EMBEDDING_URL="http://localhost:8080"

echo "🌐 Setting up real web scraping with all-MiniLM-L6-v2 embeddings..."
