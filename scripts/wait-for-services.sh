#!/bin/bash
set -e

echo "Waiting for Solr to be ready..."
while ! curl -s http://localhost:8983/solr/admin/ping >/dev/null; do
  echo "⏳ Solr not ready yet, waiting 5s..."
  sleep 5
done
echo "✅ Solr is ready!"

echo "Waiting for Storm UI to be ready..."
while ! curl -s http://localhost:8081 >/dev/null; do
  echo "⏳ Storm UI not ready yet, waiting 5s..."
  sleep 5
done
echo "✅ Storm UI is ready!"

echo "Waiting for embedding service to be ready..."
while ! curl -s http://localhost:8080/health >/dev/null; do
  echo "⏳ Embedding service not ready yet, waiting 5s..."
  sleep 5
done
echo "✅ Embedding service is ready!"
