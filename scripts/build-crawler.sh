#!/bin/bash
# Alternative simplified crawler that works without custom JAR compilation

set -e

SOLR_URL="http://localhost:8983/solr"
COLLECTION_NAME="hybrid_search"
EMBEDDING_URL="http://localhost:8080"
REDIS_HOST="localhost"
REDIS_PORT="6379"

echo "🚀 Setting up simplified crawler workflow..."

# Function to process URL queue and generate embeddings
process_crawl_queue() {
    while true; do
        # Get URL from Redis queue
        URL=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT LPOP "crawl.queue" 2>/dev/null || echo "")
        
        if [ -z "$URL" ]; then
            echo "📭 Queue empty, waiting 30s..."
            sleep 30
            continue
        fi
        
        echo "🌐 Processing: $URL"
        
        # Scrape content
        CONTENT=$(curl -s "$URL" --max-time 30 | \
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

try:
    html_content = sys.stdin.read()
    parser = TextExtractor()
    parser.feed(html_content)
    
    title = parser.title or 'Untitled'
    content = ' '.join(parser.text)
    
    # Limit content for embedding
    if len(content) > 5000:
        content = content[:5000]
    
    print(f'{title}|||{content}')
except:
    print('Error|||Error parsing content')
" 2>/dev/null || echo "Error|||Error parsing content")
        
        if [[ "$CONTENT" == *"Error"* ]] || [ -z "$CONTENT" ]; then
            echo "   ❌ Failed to extract content, requeuing..."
            redis-cli -h $REDIS_HOST -p $REDIS_PORT RPUSH "crawl.queue" "$URL" >/dev/null
            continue
        fi
        
        # Split title and content
        TITLE=$(echo "$CONTENT" | cut -d'|||' -f1)
        TEXT_CONTENT=$(echo "$CONTENT" | cut -d'|||' -f2)
        
        # Generate embedding
        echo "   🧠 Generating embedding..."
        EMBEDDING=$(curl -s "$EMBEDDING_URL/encode" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"$TEXT_CONTENT\"}" | \
            jq -r '.embedding // empty')
        
        if [ -z "$EMBEDDING" ] || [ "$EMBEDDING" == "null" ]; then
            echo "   ❌ Failed to generate embedding, skipping..."
            continue
        fi
        
        # Extract domain
        DOMAIN=$(echo "$URL" | python3 -c "
from urllib.parse import urlparse
import sys
try:
    print(urlparse(sys.stdin.read().strip()).netloc)
except:
    print('unknown')")
        
        # Index into Solr
        DOC_ID=$(echo "$URL" | sed 's/[^a-zA-Z0-9]/_/g')
        
        curl -X POST "$SOLR_URL/$COLLECTION_NAME/update" \
            -H "Content-Type: application/json" \
            -d "[{
                \"id\": \"$DOC_ID\",
                \"url\": \"$URL\",
                \"title\": \"$TITLE\",
                \"content\": \"$TEXT_CONTENT\",
                \"content_vector\": $EMBEDDING,
                \"domain\": \"$DOMAIN\",
                \"crawl_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
                \"page_rank\": 0.5,
                \"content_length\": ${#TEXT_CONTENT}
            }]" >/dev/null 2>&1 && echo "   ✅ Indexed successfully" || echo "   ❌ Indexing failed"
        
        # Commit every 10 documents
        if (( $(redis-cli -h $REDIS_HOST -p $REDIS_PORT LLEN "crawl.queue") % 10 == 0 )); then
            curl -X POST "$SOLR_URL/$COLLECTION_NAME/update" \
                -H "Content-Type: application/json" \
                -d '{"commit": {}}' >/dev/null 2>&1
        fi
        
        # Be respectful with crawl delays
        sleep 5
    done
}

# Add seed URLs
echo "📋 Adding seed URLs to queue..."
redis-cli -h $REDIS_HOST -p $REDIS_PORT LPUSH "crawl.queue" \
    "https://en.wikipedia.org/wiki/Information_retrieval" \
    "https://en.wikipedia.org/wiki/Machine_learning" \
    "https://en.wikipedia.org/wiki/Natural_language_processing" \
    "https://en.wikipedia.org/wiki/Search_engine" \
    "https://en.wikipedia.org/wiki/Apache_Solr" \
    "https://en.wikipedia.org/wiki/Vector_space_model" \
    "https://en.wikipedia.org/wiki/Learning_to_rank"

echo "🔄 Starting crawler process..."
process_crawl_queue &

echo "✅ Simplified crawler started!"
echo "📊 Queue length: $(redis-cli -h $REDIS_HOST -p $REDIS_PORT LLEN crawl.queue)"
