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
        self.title = ''
        self.in_title = False
    
    def handle_starttag(self, tag, attrs):
        if tag == 'title':
            self.in_title = True
    
    def handle_endtag(self, tag):
        if tag == 'title':
            self.in_title = False
    
    def handle_data(self, data):
        if self.in_title:
            self.title += data.strip()
        elif data.strip() and len(data.strip()) > 2:
            self.text.append(data.strip())
    
    def get_text(self):
        return ' '.join(self.text)
    
    def get_title(self):
        return self.title

try:
    html_content = sys.stdin.read()
    parser = TextExtractor()
    parser.feed(html_content)
    
    title = parser.get_title()
    content = parser.get_text()
    
    # Limit content length for embedding generation
    if len(content) > 5000:
        content = content[:5000]
    
    print(f'{title}|||{content}')
except Exception as e:
    print('Error|||Error parsing content')
")
    
    # Split title and content
    local title=$(echo "$content" | cut -d'|||' -f1)
    local text_content=$(echo "$content" | cut -d'|||' -f2)
    
    if [[ "$title" == "Error" ]] || [[ -z "$text_content" ]] || [[ ${#text_content} -lt 50 ]]; then
        echo "   ❌ Failed to extract content from $url"
        return 1
    fi
    
    echo "   📝 Title: $title"
    echo "   📏 Content length: ${#text_content} chars"
    
    # Generate embedding for the content
    echo "   🧠 Generating all-MiniLM-L6-v2 embedding..."
    local embedding_response=$(curl -s "$EMBEDDING_URL/encode" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$text_content\"}")
    
    local embedding=$(echo "$embedding_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    embedding = data.get('embedding', [])
    print(json.dumps(embedding))
except:
    print('[]')")
    
    if [[ "$embedding" == "[]" ]]; then
        echo "   ❌ Failed to generate embedding"
        return 1
    fi
    
    # Extract domain from URL
    local domain=$(echo "$url" | python3 -c "
import sys
from urllib.parse import urlparse
try:
    parsed = urlparse(sys.stdin.read().strip())
    print(parsed.netloc)
except:
    print('unknown')")
    
    # Index document into Solr with vector
    echo "   💾 Indexing into Solr..."
    local solr_doc=$(cat << EOF
{
  "id": "$doc_id",
  "url": "$url",
  "title": "$title",
  "content": "$text_content",
  "content_vector": $embedding,
  "domain": "$domain",
  "crawl_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "page_rank": 0.5,
  "content_length": ${#text_content}
}
EOF
)
    
    curl -X POST "$SOLR_URL/$COLLECTION_NAME/update" \
        -H "Content-Type: application/json" \
        -d "[$solr_doc]" || {
        echo "   ❌ Failed to index document"
        return 1
    }
    
    echo "   ✅ Successfully indexed: $title"
    return 0
}

# Real Wikipedia URLs to scrape and index
WIKIPEDIA_URLS=(
    "https://en.wikipedia.org/wiki/Information_retrieval"
    "https://en.wikipedia.org/wiki/Machine_learning"
    "https://en.wikipedia.org/wiki/Natural_language_processing"
    "https://en.wikipedia.org/wiki/Search_engine"
    "https://en.wikipedia.org/wiki/Apache_Solr"
    "https://en.wikipedia.org/wiki/Vector_space_model"
    "https://en.wikipedia.org/wiki/Learning_to_rank"
    "https://en.wikipedia.org/wiki/TF-IDF"
    "https://en.wikipedia.org/wiki/Neural_network"
    "https://en.wikipedia.org/wiki/Deep_learning"
)

echo "🚀 Starting real Wikipedia content scraping and indexing..."
echo "📊 Will process ${#WIKIPEDIA_URLS[@]} URLs with all-MiniLM-L6-v2 embeddings"

# Verify services are ready
echo "🔍 Checking service availability..."

# Check Solr
if ! curl -s "$SOLR_URL/admin/ping" | grep -q '"status":"OK"'; then
    echo "❌ Solr not ready - please run 'make up' first"
    exit 1
fi

# Check embedding service
if ! curl -s "$EMBEDDING_URL/health" | grep -q '"status":"healthy"'; then
    echo "❌ Embedding service not ready - please wait for model loading"
    exit 1
fi

echo "✅ All services ready!"

# Process each URL
successful=0
failed=0

for url in "${WIKIPEDIA_URLS[@]}"; do
    echo ""
    echo "🌐 Processing: $url"
    
    if scrape_and_index "$url"; then
        ((successful++))
        
        # Add a small delay to be respectful to Wikipedia
        sleep 2
    else
        ((failed++))
        echo "   ⚠️ Skipping due to error"
    fi
done

# Commit all changes
echo ""
echo "💾 Committing changes to Solr..."
curl -X POST "$SOLR_URL/$COLLECTION_NAME/update" \
    -H "Content-Type: application/json" \
    -d '{"commit": {}}'

# Also queue URLs for StormCrawler (if running)
echo "📋 Adding URLs to StormCrawler queue..."
for url in "${WIKIPEDIA_URLS[@]}"; do
    redis-cli -h localhost -p 6379 LPUSH "crawl.queue" "$url" >/dev/null 2>&1 || true
done

# Final status
echo ""
echo "🎉 Real Wikipedia scraping complete!"
echo "📊 Results:"
echo "   ✅ Successfully processed: $successful URLs"
echo "   ❌ Failed: $failed URLs"
echo "   📝 Total documents indexed: $(curl -s "$SOLR_URL/$COLLECTION_NAME/select?q=*:*&rows=0" | python3 -c "import json,sys; print(json.load(sys.stdin)['response']['numFound'])" 2>/dev/null || echo "Unknown")"
echo ""
echo "🔍 Ready for hybrid search queries!"
echo "   Try: make query"
