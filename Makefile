.PHONY: up down seed query setup-ltr setup-collection logs clean status

# Default target
all: setup

# Setup the complete stack
setup: up setup-collection setup-ltr seed
	@echo "✅ Complete stack is ready!"
	@echo "🔍 Solr UI: http://localhost:8983"
	@echo "🌪️  Storm UI: http://localhost:8081"
	@echo "📊 Try: make query"

# Start all services
up:
	@echo "🚀 Starting Solr + Vector Search + LTR + StormCrawler stack..."
	docker-compose up -d
	@echo "⏳ Waiting for services to be ready..."
	./scripts/wait-for-services.sh

# Stop all services
down:
	@echo "🛑 Stopping all services..."
	docker-compose down

# Setup Solr collection with vector search
setup-collection:
	@echo "📋 Creating hybrid search collection..."
	./scripts/setup-collection.sh

# Setup LTR features and models
setup-ltr:
	@echo "🎯 Setting up Learning-to-Rank..."
	./scripts/setup-ltr.sh

# Seed some URLs for crawling
seed:
	@echo "🌱 Seeding URLs for crawling..."
	./scripts/seed-urls.sh

# Run a hybrid search query with LTR re-ranking
query:
	@echo "🔍 Running hybrid search with LTR re-ranking..."
	./scripts/example-query.sh

# Monitor logs
logs:
	docker-compose logs -f

# Check status of all services
status:
	@echo "📊 Service Status:"
	@docker-compose ps
	@echo ""
	@echo "🔗 Health Checks:"
	@curl -s http://localhost:8983/solr/admin/ping | grep -o '"status":"[^"]*"' || echo "❌ Solr not ready"
	@curl -s http://localhost:8081 >/dev/null && echo "✅ Storm UI ready" || echo "❌ Storm UI not ready"

# Clean everything
clean: down
	@echo "🧹 Cleaning up volumes and data..."
	docker-compose down -v
	docker volume prune -f
