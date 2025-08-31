#!/bin/bash
set -e

    parser.feed(sys.stdin.read())
    text = parser.get_text()
    # Clean and limit text
    text = re.sub(r'\s+', ' ', text)[:5000]
    print(text)
except:
    print('')
")
    
    if [[ -z "$content" ]]; then
        echo "❌ Failed to scrape content from $url"
        return
    fi
    
    # Extract title from content (first substantial line)
    local title=$(echo "$content" | head -c 200 | sed 's/[^a-zA-Z0-9 ]//g' | head -1)
    local domain=$(echo "$url" | sed -E 's|https?://([^/]+).*|\1|')
    
    echo "🧠 Generating embedding for: $title"
    
    # Generate real embedding using all-MiniLM-L6-v2
    local embedding=$(curl -s "$EMBEDDING_URL/encode" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$content\"}" | jq -r '.embedding')
    
    if [[ "$embedding" == "null" || -z "$embedding" ]]; then
        echo "❌ Failed to generate embedding for $url"
        return
    fi
    
    echo "📝 Indexing document with real vector..."
    
    # Index document with real scraped content and generated vector
    curl -X POST "$SOLR_URL/$COLLECTION_NAME/update" \
        -H "Content-Type: application/json" \
        -d "[{
            \"id\": \"$doc_id\",
            \"url\": \"$url\",
            \"title\": \"$title\",
            \"content\": \"$content\",
            \"content_vector\": $embedding,
            \"domain\": \"$domain\",
            \"crawl_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
            \"page_rank\": 0.7,
            \"content_length\": ${#content}
        }]"
    
    echo "✅ Successfully indexed: $title"
}

# Wait for embedding service to be ready
echo "⏳ Waiting for embedding service..."
while ! curl -s "$EMBEDDING_URL/health" >/dev/null; do
    echo "Waiting for all-MiniLM-L6-v2 service..."
    sleep 5
done
echo "✅ Embedding service ready!"

# Scrape and index real Wikipedia pages with actual embeddings
echo "🔄 Scraping real content and generating embeddings..."

scrape_and_index "https://en.wikipedia.org/wiki/Information_retrieval"
scrape_and_index "https://en.wikipedia.org/wiki/Machine_learning" 
scrape_and_index "https://en.wikipedia.org/wiki/Natural_language_processing"

# Commit all changes
curl -X POST "$SOLR_URL/$COLLECTION_NAME/update" \
    -H "Content-Type: application/json" \
    -d '{"commit": {}}'

# Also add URLs to StormCrawler queue for continuous crawling
echo "📋 Adding URLs to StormCrawler queue for continuous crawling..."
redis-cli -h localhost -p 6379 LPUSH "crawl.queue" \
    "https://en.wikipedia.org/wiki/Information_retrieval" \
    "https://en.wikipedia.org/wiki/Machine_learning" \
    "https://en.wikipedia.org/wiki/Natural_language_processing" \
    "https://en.wikipedia.org/wiki/Deep_learning" \
    "https://en.wikipedia.org/wiki/Computer_vision" \
    "https://en.wikipedia.org/wiki/Artificial_intelligence"

echo ""
echo "✅ Real content indexed with all-MiniLM-L6-v2 embeddings!"
echo "📊 Check indexed documents: curl -s 'http://localhost:8983/solr/hybrid_search/select?q=*:*&rows=0' | jq '.response.numFound'"
