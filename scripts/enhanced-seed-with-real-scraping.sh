#!/bin/bash
set -e

SOLR_URL="http://localhost:8983/solr"
COLLECTION_NAME="hybrid_search"
EMBEDDING_URL="http://localhost:8080"

echo "🌐 Setting up real web scraping with all-MiniLM-L6-v2 embeddings..."

# Function to scrape URL and generate embedding
scrape_and_index() {
    local url=$1
    local doc_id=$(echo "$url" | sed 's/[^a-zA-Z0-9]/_/g')
    
    echo "📄 Scraping: $url"
    
    # Scrape content using curl and basic parsing
    local content=$(curl -s "$url" | \
        python3 -c "
import sys, re
from html.parser import HTMLParser
class TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.text = []
    def handle_data(self, data):
        if data.strip():
            self.text.append(data.strip())
    def get_text(self):
        return ' '.join(self.text)

parser = TextExtractor()
try:  # Indexer configuration with vector field mapping
  indexer.class: "com.digitalpebble.stormcrawler.solr.SolrIndexer"
  indexer.url.fieldname: "url"
  indexer.text.fieldname: "content"
  indexer.title.fieldname: "title"
  indexer.domain.fieldname: "domain"
  indexer.date.fieldname: "crawl_date"
  
  # Vector embedding configuration
  embedding.service.url: "http://embedding-service:8080"
  embedding.field.name: "content_vector"
  embedding.model: "all-MiniLM-L6-v2"
  embedding.dimension: 384
  
  # Content processing
  content.max.length: 5000  # Limit for embedding generation
  
  # Solr specific indexing
  solr.indexer.doc.buffer: 100
  solr.indexer.delete.by.query: false# Complete Solr + Vector Search + LTR + StormCrawler Implementation
# This stack provides: Hybrid retrieval (BM25 + vectors), LTR re-ranking, and web crawling
