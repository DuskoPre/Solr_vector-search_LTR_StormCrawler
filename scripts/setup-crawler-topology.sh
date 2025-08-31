#!/bin/bash
set -e

echo "Setting up StormCrawler topology..."

# Wait for Storm to be ready
while ! curl -s http://localhost:8081 >/dev/null; do
  echo "Waiting for Storm UI..."
  sleep 5
done

# Submit crawler topology
docker exec storm-nimbus storm jar \
  /opt/stormcrawler/crawler-solr-1.0.jar \
  org.apache.stormcrawler.solr.SolrCrawlTopology \
  -conf /storm-configs/crawler-conf.yaml \
  hybrid-crawler

echo "✅ Crawler topology submitted!"

---
# File: docker-compose.override.yml
# Override file to customize the Chorus setup with Hello-LTR Solr
version: '3.8'

services:
  solr:
    image: o19s/hello-ltr-solr:latest
    environment:
      - SOLR_HEAP=4g
      - SOLR_OPTS=-Dsolr.modules=ltr
    volumes:
      - ./solr-home:/var/solr/data
      # Mount custom configs if needed
      - ./solr-configs:/opt/solr/server/solr/configsets/custom
