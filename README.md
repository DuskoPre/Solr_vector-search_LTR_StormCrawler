# Solr_vector-search_LTR_StormCrawler
Solr with hybrid retrieval (BM25 + vectors) from Chorus + Learning-to-Rank (LTR) second-pass re-rank (via Hello-LTR configs) + (Optional) a crawler (StormCrawler) that feeds Solr

# Complete Workflow Procedure: Solr + Vector Search + LTR + StormCrawler

## 📋 **Prerequisites Setup**

### 1. Install Required Software
```bash
# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# Install Git
sudo apt update && sudo apt install git make curl jq redis-tools -y

# Verify installations
docker --version
docker-compose --version
git --version
make --version
```

### 2. System Requirements Check
```bash
# Ensure sufficient resources
free -h    # Minimum 8GB RAM recommended
df -h      # Minimum 10GB free disk space
```

## 🚀 **Initial Setup Workflow**

### Step 1: Clone and Prepare Environment
```bash
# Create project directory
mkdir solr-search-stack && cd solr-search-stack

# Make all script files executable
chmod +x scripts/*.sh

# Create necessary directories
mkdir -p {solr-home,solr-configs,storm-configs,crawler-topology,logs}
```

### Step 2: Start the Complete Stack
```bash
# This single command does everything:
make setup
```

**What `make setup` does behind the scenes:**
1. ✅ Starts all Docker containers (`make up`)
2. ✅ Waits for services to be healthy
3. ✅ Creates Solr collection with vector fields (`setup-collection`)
4. ✅ Configures LTR features and models (`setup-ltr`)
5. ✅ Seeds initial URLs and sample data (`seed`)

### Step 3: Verify Everything is Running
```bash
# Check service status
make status

# Expected output:
# 📊 Service Status:
# ✅ Solr ready
# ✅ Storm UI ready  
# ✅ Redis ready
# ✅ Embedding service ready
```

## 🔍 **Search and Query Workflow**

### Step 4: Run Example Queries
```bash
# Run comprehensive search examples
make query
```

**What this demonstrates:**
1. **Pure BM25 search** - Traditional keyword matching
2. **Pure vector search** - Semantic similarity
3. **Hybrid search + LTR** - Best of both worlds with re-ranking

### Step 5: Manual Query Examples

#### A. Basic Keyword Search (BM25)
```bash
curl "http://localhost:8983/solr/hybrid_search/select" \
  -d "q=artificial intelligence&defType=edismax&qf=title^2 content&rows=10&fl=id,title,score"
```

#### B. Pure Vector/Semantic Search
```bash
# First, get vector for your query
QUERY_VECTOR=$(curl -s "http://localhost:8080/encode" \
  -H "Content-Type: application/json" \
  -d '{"text": "machine learning algorithms"}' | jq -r '.embedding')

# Then search using that vector
curl "http://localhost:8983/solr/hybrid_search/select" \
  -d "q={!knn f=content_vector topK=10}${QUERY_VECTOR}&fl=id,title,score"
```

#### C. Hybrid Search with LTR Re-ranking (Recommended)
```bash
curl "http://localhost:8983/solr/hybrid_search/select" \
  -d "q=machine learning&defType=edismax&qf=title^2 content&rq={!ltr model=hybrid_ranker reRankDocs=20}&rows=10&fl=id,title,score,[features]"
```

## 🌐 **Web Crawling Workflow**

### Step 6: Add URLs for Crawling
```bash
# Add single URL
redis-cli -h localhost -p 6379 LPUSH "crawl.queue" "https://en.wikipedia.org/wiki/Information_retrieval"

# Add multiple URLs at once
redis-cli -h localhost -p 6379 LPUSH "crawl.queue" \
  "https://pytorch.org/tutorials/" \
  "https://scikit-learn.org/stable/user_guide.html" \
  "https://docs.python.org/3/tutorial/"

# Check queue length
redis-cli -h localhost -p 6379 LLEN "crawl.queue"
```

### Step 7: Monitor Crawling Progress
```bash
# Watch Storm topology (crawler) status
curl -s "http://localhost:8081/api/v1/topology/summary" | jq '.topologies[]'

# Check how many documents are indexed
curl -s "http://localhost:8983/solr/hybrid_search/select?q=*:*&rows=0" | jq '.response.numFound'

# View recent crawl logs
docker logs storm-crawler --tail 50
```

## 📊 **Monitoring and Management Workflow**

### Step 8: Regular Monitoring
```bash
# Check overall system health
make status

# Monitor service logs in real-time
make logs

# Check specific service logs
docker logs solr-ltr --tail 100
docker logs storm-crawler --tail 100
docker logs embedding-service --tail 100
```

### Step 9: Performance Monitoring
```bash
# Check Solr query performance
curl -s "http://localhost:8983/solr/admin/metrics?group=core&prefix=QUERY" | jq

# Monitor index size and document count
curl -s "http://localhost:8983/solr/hybrid_search/admin/luke?numTerms=0" | jq '.index'

# Check Redis queue statistics
redis-cli -h localhost -p 6379 INFO memory
redis-cli -h localhost -p 6379 LLEN "crawl.queue"
```

## 🔧 **Operational Workflow**

### Step 10: Adding New Content

#### Manual Document Addition
```bash
# Add document with automatic vector generation
curl -X POST "http://localhost:8983/solr/hybrid_search/update" \
  -H "Content-Type: application/json" \
  -d '[{
    "id": "manual_doc_1",
    "url": "https://example.com/manual",
    "title": "Manually Added Document",
    "content": "This is content that will be automatically vectorized",
    "domain": "example.com",
    "crawl_date": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "page_rank": 0.5,
    "content_length": 50
  }]'

# Commit the changes
curl -X POST "http://localhost:8983/solr/hybrid_search/update" \
  -H "Content-Type: application/json" \
  -d '{"commit": {}}'
```

#### Bulk URL Addition for Crawling
```bash
# Add many URLs from a file
cat urls.txt | while read url; do
  redis-cli -h localhost -p 6379 LPUSH "crawl.queue" "$url"
done
```

### Step 11: Query Analysis and Tuning

#### Analyze Query Performance
```bash
# Query with debug information
curl "http://localhost:8983/solr/hybrid_search/select" \
  -d "q=machine learning&defType=edismax&qf=title^2 content&debugQuery=true&rq={!ltr model=hybrid_ranker reRankDocs=20}&fl=id,title,score,[features]" | \
  jq '.debug'
```

#### Test LTR Feature Extraction
```bash
# See what features are being calculated
curl "http://localhost:8983/solr/hybrid_search/select" \
  -d "q=artificial intelligence&rq={!ltr model=hybrid_ranker reRankDocs=10}&fl=id,title,[features]" | \
  jq '.response.docs[0]."[features]"'
```

## 🛠️ **Maintenance Workflow**

### Step 12: Regular Maintenance Tasks

#### Daily Operations
```bash
# Check system health
make status

# Monitor crawl progress
echo "Documents indexed: $(curl -s 'http://localhost:8983/solr/hybrid_search/select?q=*:*&rows=0' | jq '.response.numFound')"
echo "URLs in queue: $(redis-cli -h localhost -p 6379 LLEN 'crawl.queue')"

# Check for errors in logs
docker logs solr-ltr --since 24h | grep -i error
docker logs storm-crawler --since 24h | grep -i error
```

#### Weekly Operations
```bash
# Optimize Solr index
curl -X POST "http://localhost:8983/solr/hybrid_search/update" \
  -d '<optimize/>'

# Backup Solr data
docker exec solr-ltr solr create_backup -c hybrid_search -b weekly_backup

# Clean old crawl data if needed
redis-cli -h localhost -p 6379 FLUSHDB  # Only if queue is too large
```

### Step 13: Scaling Operations

#### Scale Up Crawling
```bash
# Increase crawler parallelism
docker-compose up -d --scale supervisor=3

# Add more URLs in batches
for i in {1..100}; do
  redis-cli -h localhost -p 6379 LPUSH "crawl.queue" "https://example.com/page$i"
done
```

#### Scale Up Search Performance
```bash
# Increase Solr heap (edit docker-compose.yml)
# Change: SOLR_HEAP=4g to SOLR_HEAP=8g
docker-compose up -d solr
```

## 🎯 **End-to-End Workflow Example**

### Complete Example: From Zero to Search Results
```bash
# 1. Start everything
make setup
# ⏳ Wait 2-3 minutes for full initialization

# 2. Add some real URLs to crawl
redis-cli -h localhost -p 6379 LPUSH "crawl.queue" \
  "https://en.wikipedia.org/wiki/Machine_learning" \
  "https://en.wikipedia.org/wiki/Natural_language_processing" \
  "https://en.wikipedia.org/wiki/Computer_vision"

# 3. Wait for crawling (check progress)
watch -n 30 'echo "Queue: $(redis-cli -h localhost -p 6379 LLEN crawl.queue) | Indexed: $(curl -s "http://localhost:8983/solr/hybrid_search/select?q=*:*&rows=0" | jq .response.numFound)"'

# 4. Run your first hybrid search
curl "http://localhost:8983/solr/hybrid_search/select" \
  -d "q=neural networks&defType=edismax&qf=title^2 content&rq={!ltr model=hybrid_ranker reRankDocs=20}&rows=5&fl=id,title,url,score" | \
  jq '.response.docs[]'

# 5. Analyze the results
curl "http://localhost:8983/solr/hybrid_search/select" \
  -d "q=neural networks&rq={!ltr model=hybrid_ranker reRankDocs=10}&fl=id,title,[features]" | \
  jq '.response.docs[0]."[features]"'
```

## 🚨 **Troubleshooting Workflow**

### Common Issues and Solutions

#### Service Won't Start
```bash
# Check what's wrong
docker-compose ps
docker logs <service-name>

# Common fixes
docker-compose down && docker-compose up -d
# Or restart specific service:
docker-compose restart solr
```

#### No Search Results
```bash
# Check if documents are indexed
curl -s "http://localhost:8983/solr/hybrid_search/select?q=*:*&rows=0" | jq '.response.numFound'

# If 0 documents, check crawler:
redis-cli -h localhost -p 6379 LLEN "crawl.queue"
docker logs storm-crawler --tail 20
```

#### LTR Not Working
```bash
# Verify LTR models are loaded
curl -s "http://localhost:8983/solr/hybrid_search/schema/model-store" | jq

# Re-setup LTR if needed
make setup-ltr
```

## 📈 **Production Deployment Workflow**

### Step 14: Production Considerations
```bash
# 1. Update resource limits in docker-compose.yml
# 2. Set up proper backup strategy
# 3. Configure monitoring (Prometheus/Grafana)
# 4. Set up log rotation
# 5. Configure SSL/TLS for external access
# 6. Set up reverse proxy (Nginx/Apache)
```

This workflow gives you a complete operational procedure from initial setup through daily operations, scaling, and troubleshooting. The beauty of this stack is that once you run `make setup`, you have a fully functional hybrid search system with machine learning re-ranking and continuous web crawling - all running locally and completely free!
