#!/bin/bash
set -e

SOLR_URL="http://localhost:8983/solr"
COLLECTION_NAME="hybrid_search"

echo "Setting up Learning-to-Rank features and models..."

# Create feature store
curl -X PUT "$SOLR_URL/$COLLECTION_NAME/schema/feature-store" \
  -H "Content-Type: application/json" \
  -d '{
    "store": "hybrid_features",
    "features": [
      {
        "name": "bm25_score",
        "class": "org.apache.solr.ltr.feature.SolrFeature",
        "params": {
          "q": "{!edismax qf=\"title^2 content\" v=\"${user_query}\"}"
        }
      },
      {
        "name": "vector_similarity",
        "class": "org.apache.solr.ltr.feature.SolrFeature",
        "params": {
          "q": "{!knn f=content_vector topK=10}${user_vector}"
        }
      },
      {
        "name": "title_match",
        "class": "org.apache.solr.ltr.feature.SolrFeature",
        "params": {
          "q": "title:${user_query}"
        }
      },
      {
        "name": "domain_authority",
        "class": "org.apache.solr.ltr.feature.FieldValueFeature",
        "params": {
          "field": "page_rank"
        }
      },
      {
        "name": "content_length",
        "class": "org.apache.solr.ltr.feature.FieldValueFeature",
        "params": {
          "field": "content_length"
        }
      },
      {
        "name": "recency",
        "class": "org.apache.solr.ltr.feature.SolrFeature",
        "params": {
          "q": "{!func}recip(ms(NOW,crawl_date),3.16e-11,1,1)"
        }
      }
    ]
  }'

# Upload LambdaMART model
curl -X PUT "$SOLR_URL/$COLLECTION_NAME/schema/model-store" \
  -H "Content-Type: application/json" \
  -d '{
    "store": "hybrid_model",
    "class": "org.apache.solr.ltr.model.LambdaMARTModel",
    "name": "hybrid_ranker",
    "features": [
      {"name": "bm25_score"},
      {"name": "vector_similarity"},
      {"name": "title_match"},
      {"name": "domain_authority"},
      {"name": "content_length"},
      {"name": "recency"}
    ],
    "params": {
      "trees": [
        {
          "weight": 1.0,
          "root": {
            "feature": "bm25_score",
            "threshold": 0.5,
            "left": {"value": 0.1},
            "right": {
              "feature": "vector_similarity",
              "threshold": 0.7,
              "left": {"value": 0.3},
              "right": {"value": 0.8}
            }
          }
        },
        {
          "weight": 0.8,
          "root": {
            "feature": "title_match",
            "threshold": 0.1,
            "left": {
              "feature": "recency",
              "threshold": 0.5,
              "left": {"value": 0.2},
              "right": {"value": 0.4}
            },
            "right": {"value": 0.6}
          }
        }
      ]
    }
  }'

echo "✅ LTR setup complete!"
