# Solr + Vector Search + LTR + StormCrawler Stack

This is a complete implementation of a hybrid search system combining:
- **Solr** with vector search capabilities
- **Learning-to-Rank (LTR)** for second-pass re-ranking
- **StormCrawler** for continuous web crawling
- **Vector embeddings** for semantic search

## Quick Start

1. **Clone and start the stack:**
   ```bash
   git clone <this-repo>
   cd solr-vector-ltr-stack
   make setup
   ```

2. **Access the services:**
   - Solr UI: http://localhost:8983
   - Storm UI: http://localhost:8081
   - Redis: localhost:6379

3. **Run example queries:**
   ```bash
   make query
   ```

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   StormCrawler  │───▶│   Solr + Vector  │◀───│  Query Interface│
│   (Web Crawler) │    │   + LTR Ranking  │    │   (Hybrid Search)│
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         ▼                        ▼                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│      Redis      │    │   Vector Store   │    │   Search Results│
│  (URL Frontier) │    │   (Embeddings)   │    │  (BM25+Vector+LTR)│
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Features

### 🔍 Hybrid Retrieval
- **BM25** for keyword matching
- **Dense Vector Search** with HNSW for semantic similarity
- **Combined scoring** for best of both worlds

### 🎯 Learning-to-Rank
- **LambdaMART model** for second-pass re-ranking
- **Multiple features**: BM25 score, vector similarity, title match, domain authority, content length, recency
- **Configurable re-ranking** of top-N documents

### 🌐 Web Crawling
- **StormCrawler** for distributed web crawling
- **Redis-based URL frontier** for scalable crawling
- **Automatic indexing** into Solr with vector embeddings

### ⚡ Performance Features
- **HNSW indexing** for fast vector search
- **Configurable caching** for LTR feature vectors
- **Distributed processing** with Apache Storm

## Usage Examples

### Basic Hybrid Search
```bash
curl "http://localhost:8983/solr/hybrid_search/select" \
  -d "q=machine learning&defType=edismax&qf=title^2 content&rows=10"
```

### Vector Search Only
```bash
curl "http://localhost:8983/solr/hybrid_search/select" \
  -d "q={!knn f=content_vector topK=10}[0.1,0.2,0.3,...]&fl=id,title,score"
```

### Hybrid Search with LTR Re-ranking
```bash
curl "http://localhost:8983/solr/hybrid_search/select" \
  -d "q=machine learning&defType=edismax&qf=title^2 content&rq={!ltr model=hybrid_ranker reRankDocs=20}&fl=id,title,score,[features]"
```

### Add URLs for Crawling
```bash
redis-cli -h localhost -p 6379 LPUSH "crawl.queue" "https://example.com/new-page"
```

## Configuration

### Vector Field Configuration
The schema includes a `content_vector` field with:
- **384 dimensions** (matches sentence-transformers/all-MiniLM-L6-v2)
- **Cosine similarity** function
- **HNSW algorithm** with optimized parameters

### LTR Features
The system includes 6 ranking features:
1. **BM25 Score** - Traditional keyword relevance
2. **Vector Similarity** - Semantic similarity score
3. **Title Match** - Boost for title keyword matches
4. **Domain Authority** - Page rank score
5. **Content Length** - Document length signal
6. **Recency** - Time-based freshness score

### StormCrawler Configuration
- **Politeness**: 5-second crawl delay
- **Content limit**: 1MB per page
- **Robots.txt compliance**: Enabled
- **Redis URL frontier**: Scalable queue management

## Management Commands

```bash
# Start the entire stack
make up

# Stop everything
make down

# View logs
make logs

# Check service status
make status

# Clean everything (including data)
make clean

# Re-setup LTR models
make setup-ltr

# Add more seed URLs
make seed
```

## Monitoring

### Solr Admin UI (http://localhost:8983)
- Collection status and statistics
- Query performance metrics
- Index size and document count
- LTR model and feature management

### Storm UI (http://localhost:8081)
- Crawler topology status
- Processing throughput
- Error monitoring
- Worker node status

### Key Metrics to Monitor
- **Index size**: Number of documents indexed
- **Crawl rate**: Pages per minute processed
- **Query latency**: Response times for hybrid search
- **LTR performance**: Re-ranking improvement metrics

## Customization

### Adding New LTR Features
Edit `scripts/setup-ltr.sh` and add features to the feature store:
```json
{
  "name": "custom_feature",
  "class": "org.apache.solr.ltr.feature.SolrFeature",
  "params": {
    "q": "your_custom_query"
  }
}
```

### Adjusting Vector Dimensions
1. Update `vectorDimension` in schema.xml
2. Update embedding service model
3. Recreate the collection

### Crawler Filtering
Edit `storm-configs/crawler-conf.yaml` to:
- Add URL patterns to crawl/exclude
- Adjust politeness settings
- Configure content extraction rules

## Troubleshooting

### Common Issues

**Solr not starting:**
```bash
docker logs solr-ltr
# Check SOLR_HEAP and port conflicts
```

**StormCrawler not processing:**
```bash
# Check Storm topology status
curl http://localhost:8081/api/v1/topology/summary
```

**Vector search not working:**
```bash
# Verify vector field exists
curl "http://localhost:8983/solr/hybrid_search/schema/fields/content_vector"
```

**LTR models not loading:**
```bash
# Check feature and model stores
curl "http://localhost:8983/solr/hybrid_search/schema/feature-store"
curl "http://localhost:8983/solr/hybrid_search/schema/model-store"
```

### Performance Tuning

**For high-volume crawling:**
- Increase Storm worker nodes
- Adjust `fetcher.threads.number` in crawler config
- Scale Redis or use Redis Cluster

**For faster queries:**
- Increase Solr heap size (`SOLR_HEAP`)
- Tune HNSW parameters (`maxConn`, `beamWidth`)
- Adjust LTR cache size

**For better ranking:**
- Train LTR models on your specific data
- Add domain-specific features
- Fine-tune feature weights

## Integration with External Systems

### Embedding Service Integration
The stack includes a sentence-transformers service for generating vectors:
```python
import requests
response = requests.post('http://localhost:8080/encode', 
                        json={'text': 'your text here'})
vector = response.json()['embedding']
```

### API Integration
Use Solr's REST API for programmatic access:
```python
import requests

# Hybrid search with LTR
response = requests.get('http://localhost:8983/solr/hybrid_search/select', params={
    'q': 'your query',
    'defType': 'edismax',
    'qf': 'title^2 content',
    'rq': '{!ltr model=hybrid_ranker reRankDocs=20}',
    'fl': 'id,title,score,[features]'
})
results = response.json()['response']['docs']
```

## Advanced Features

### Real-time Indexing
The crawler continuously adds new documents. For immediate indexing:
```bash
curl -X POST "http://localhost:8983/solr/hybrid_search/update" \
  -H "Content-Type: application/json" \
  -d '{"add": {"doc": {"id": "new_doc", "title": "...", "content": "..."}}}'
```

### Custom Similarity Functions
Modify the vector field type to use different similarity functions:
- `cosine` - Cosine similarity (default)
- `dot_product` - Dot product similarity  
- `euclidean` - Euclidean distance

### Multi-language Support
Add language detection and language-specific analyzers:
```xml
<fieldType name="text_en" class="solr.TextField">
  <analyzer type="index">
    <tokenizer class="solr.StandardTokenizerFactory"/>
    <filter class="solr.EnglishPossessiveFilterFactory"/>
    <filter class="solr.LowerCaseFilterFactory"/>
    <filter class="solr.EnglishMinimalStemFilterFactory"/>
  </analyzer>
</fieldType>
```

This implementation provides a production-ready foundation for hybrid search with learning-to-rank capabilities, complete with automated crawling and vector embeddings.
