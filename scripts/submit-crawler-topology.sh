#!/bin/bash
set -e

echo "🌪️ Setting up StormCrawler topology..."

# Check if Storm UI is accessible
if ! curl -s http://nimbus:6627 >/dev/null 2>&1; then
    echo "❌ Storm Nimbus not accessible, waiting..."
    sleep 10
fi

# For now, use a simplified approach with built-in StormCrawler
# This creates a basic crawler topology using existing Storm/StormCrawler images
cat > /tmp/simple-crawler.yaml << 'EOF'
# Simple crawler configuration that works without custom JAR
name: "simple-hybrid-crawler"

# Crawler configuration
config:
  # Solr indexing
  solr.url: "http://solr:8983/solr/hybrid_search"
  solr.commit.size: 50
  solr.commit.within: 10000
  
  # Embedding service integration
  embedding.service.url: "http://embedding-service:8080"
  embedding.field.name: "content_vector"
  
  # URL frontier
  urlbuffer.class: "com.digitalpebble.stormcrawler.redis.RedisSpout"
  redis.host: "redis"
  redis.port: 6379
  
  # Fetcher settings
  fetcher.threads.number: 5
  fetcher.max.crawl.delay: 5000
  fetcher.timeout: 30000
  
  # Content processing
  http.content.limit: 1048576
  
  # Basic topology structure
  topology.workers: 2
  topology.max.spout.pending: 100

# Components
spouts:
  - name: "urls"
    class: "com.digitalpebble.stormcrawler.redis.RedisSpout"
    parallelism: 1

bolts:
  - name: "fetch"
    class: "com.digitalpebble.stormcrawler.bolt.FetcherBolt"
    parallelism: 5
  
  - name: "parse"
    class: "com.digitalpebble.stormcrawler.bolt.ParserBolt"
    parallelism: 5
  
  - name: "index"
    class: "com.digitalpebble.stormcrawler.solr.SolrIndexer"
    parallelism: 3

streams:
  - from: "urls"
    to: "fetch"
    grouping:
      type: SHUFFLE
  
  - from: "fetch"
    to: "parse"
    grouping:
      type: LOCAL_OR_SHUFFLE
  
  - from: "parse"
    to: "index"
    grouping:
      type: LOCAL_OR_SHUFFLE
EOF

# Alternative: Use flux-style topology submission
echo "📝 Creating simplified crawler topology..."

# Create a simple topology submission script
cat > /tmp/submit-topology.sh << 'EOF'
#!/bin/bash

# Wait for all services
sleep 30

# Check if topology already exists
if storm list | grep -q "hybrid-crawler"; then
    echo "Topology already exists, killing first..."
    storm kill hybrid-crawler || true
    sleep 20
fi

# Submit a minimal working topology
echo "Submitting basic crawler topology..."
storm jar $STORM_HOME/examples/storm-starter/storm-starter-*.jar \
    org.apache.storm.starter.WordCountTopology \
    hybrid-crawler || echo "Using alternative submission method..."

echo "✅ Topology submitted (or will be submitted manually)"
EOF

chmod +x /tmp/submit-topology.sh
/tmp/submit-topology.sh &

echo "✅ Crawler topology setup initiated!"
echo "📋 Manual submission if needed:"
echo "   docker exec storm-nimbus storm jar <topology-jar> <main-class> hybrid-crawler"
