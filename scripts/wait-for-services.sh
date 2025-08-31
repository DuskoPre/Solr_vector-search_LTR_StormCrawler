#!/bin/bash
set -e

echo "🚀 Waiting for all services to be ready..."

echo "⏳ Waiting for Solr..."
while ! curl -s http://localhost:8983/solr/admin/ping >/dev/null 2>&1; do
  echo "   Solr not ready yet, waiting 5s..."
  sleep 5
done
echo "✅ Solr is ready!"

echo "⏳ Waiting for Redis..."
while ! redis-cli -h localhost -p 6379 ping >/dev/null 2>&1; do
  echo "   Redis not ready yet, waiting 5s..."
  sleep 5
done
echo "✅ Redis is ready!"

echo "⏳ Waiting for embedding service (all-MiniLM-L6-v2)..."
timeout=180  # 3 minutes timeout for model loading
elapsed=0
while ! curl -s http://localhost:8080/health >/dev/null 2>&1; do
  if [ $elapsed -ge $timeout ]; then
    echo "❌ Timeout waiting for embedding service"
    echo "📋 Check logs: docker logs embedding-service"
    exit 1
  fi
  echo "   Loading all-MiniLM-L6-v2 model... (${elapsed}s elapsed)"
  sleep 10
  elapsed=$((elapsed + 10))
done
echo "✅ all-MiniLM-L6-v2 embedding service is ready!"

echo "⏳ Waiting for Storm UI..."
while ! curl -s http://localhost:8081 >/dev/null 2>&1; do
  echo "   Storm UI not ready yet, waiting 5s..."
  sleep 5
done
echo "✅ Storm UI is ready!"

echo ""
echo "🎉 All services are ready!"
echo "🔗 Access points:"
echo "   📊 Solr Admin: http://localhost:8983"
echo "   🌪️  Storm UI: http://localhost:8081" 
echo "   🧠 Embeddings: http://localhost:8080/health"
echo "   📝 Redis: localhost:6379"
