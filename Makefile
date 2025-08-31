# Makefile with real all-MiniLM-L6-v2 embeddings and Wikipedia scraping
.PHONY: up down seed query setup-ltr setup-collection logs clean status real-scrape

# Default target - complete setup with real embeddings
all: setup

# Setup the complete stack with real Wikipedia content
setup: up setup-collection setup-ltr real-scrape
	@echo ""
	@echo "🎉 Complete hybrid search stack is ready!"
	@echo "📊 Features:"
	@echo "   ✅ Solr with vector search (all-MiniLM-L6-v2, 384 dims)"
	@echo "   ✅ LTR re-ranking with 6 features"
	@echo "   ✅ Real Wikipedia content scraped and vectorized"
	@echo "   ✅ StormCrawler for continuous crawling"
	@echo ""
	@echo "🔗 Access Points:"
	@echo "   📊 Solr UI: http://localhost:8983"
	@echo "   🌪️  Storm UI: http://localhost:8081"
	@echo "   🧠 Embeddings: http://localhost:8080/health"
	@echo ""
	@echo "🚀 Next Steps:"
	@echo "   📋 Try: make query"
	@echo "   📈 Monitor: make status"
	@echo "   🔍 Add URLs: make add-urls"

# Start all services
up:
	@echo "🚀 Starting Solr + Vector Search + LTR + StormCrawler stack..."
	docker-compose up -d
	@echo "⏳ Waiting for services (all-MiniLM-L6-v2 model loading may take 1-2 minutes)..."
	./scripts/wait-for-services.sh

# Stop all services
down:
	@echo "🛑 Stopping all services..."
	docker-compose down

# Setup Solr collection with 384-dimensional vector search (all-MiniLM-L6-v2)
setup-collection:
	@echo "📋 Creating hybrid search collection (384-dim vectors)..."
	./scripts/setup-collection.sh

# Setup LTR features and models
setup-ltr:
	@echo "🎯 Setting up Learning-to-Rank with 6 features..."
	./scripts/setup-ltr.sh

# Scrape real Wikipedia content and generate actual embeddings
real-scrape:
	@echo "🌐 Scraping real Wikipedia content with all-MiniLM-L6-v2 embeddings..."
	./scripts/enhanced-seed-with-real-scraping.sh

# Run comprehensive query examples with real embeddings
query:
	@echo "🔍 Running real-world queries with all-MiniLM-L6-v2..."
	./scripts/real-world-query-examples.sh

# Add more URLs for crawling
add-urls:
	@echo "📋 Adding more URLs to crawl queue..."
	@echo "Enter URLs (one per line, empty line to finish):"
	@while read -r url; do \
		if [ -z "$url" ]; then break; fi; \
		redis-cli -h localhost -p 6379 LPUSH "crawl.queue" "$url"; \
		echo "  ✅ Added: $url"; \
	done
	@echo "📊 Queue length: $(redis-cli -h localhost -p 6379 LLEN 'crawl.queue')"

# Monitor logs from all services
logs:
	docker-compose logs -f

# Check detailed status of all services and data
status:
	@echo "📊 === HYBRID SEARCH STACK STATUS ==="
	@echo ""
	@echo "🐳 Docker Services:"
	@docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "🔗 Health Checks:"
	@printf "   Solr: "
	@curl -s http://localhost:8983/solr/admin/ping 2>/dev/null | grep -q '"status":"OK"' && echo "✅ Ready" || echo "❌ Not Ready"
	@printf "   Storm UI: "
	@curl -s http://localhost:8081 >/dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"
	@printf "   Embeddings (all-MiniLM-L6-v2): "
	@curl -s http://localhost:8080/health 2>/dev/null | grep -q '"status":"healthy"' && echo "✅ Ready" || echo "❌ Not Ready"
	@printf "   Redis: "
	@redis-cli -h localhost -p 6379 ping >/dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"
	@echo ""
	@echo "📈 Data Statistics:"
	@printf "   Documents indexed: "
	@curl -s "http://localhost:8983/solr/hybrid_search/select?q=*:*&rows=0" 2>/dev/null | jq -r '.response.numFound // "Error"'
	@printf "   URLs in crawl queue: "
	@redis-cli -h localhost -p 6379 LLEN "crawl.queue" 2>/dev/null || echo "Error"
	@printf "   Index size: "
	@curl -s "http://localhost:8983/solr/hybrid_search/admin/luke?numTerms=0" 2>/dev/null | jq -r '.index.sizeInBytes // "Error"' | numfmt --to=iec 2>/dev/null || echo "Error"
	@echo ""
	@echo "🎯 LTR Model Status:"
	@curl -s "http://localhost:8983/solr/hybrid_search/schema/model-store" 2>/dev/null | jq -r '.models[]?.name // "No models found"'

# Test embedding service specifically
test-embeddings:
	@echo "🧠 Testing all-MiniLM-L6-v2 embedding service..."
	@echo "Query: 'machine learning algorithms'"
	@curl -s "http://localhost:8080/encode" \
		-H "Content-Type: application/json" \
		-d '{"text": "machine learning algorithms"}' | \
		jq '{model: .model, dimension: .dimension, first_5_values: .embedding[0:5]}'

# Run performance benchmarks
benchmark:
	@echo "⚡ Running performance benchmarks..."
	@echo "Testing query latency (10 queries)..."
	@for i in {1..10}; do \
		time curl -s "http://localhost:8983/solr/hybrid_search/select?q=machine+learning&defType=edismax&qf=title^2+content&rq={!ltr+model=hybrid_ranker+reRankDocs=20}&rows=5" >/dev/null; \
	done

# Clean everything including data
clean: down
	@echo "🧹 Cleaning up all data and volumes..."
	docker-compose down -v
	docker volume prune -f
	docker system prune -f
	@echo "✅ Cleanup complete!"
