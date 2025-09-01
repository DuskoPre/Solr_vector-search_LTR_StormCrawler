#!/bin/bash
set -e

SOLR_URL="http://localhost:8983/solr"
COLLECTION_NAME="hybrid_search"

echo "🎯 Setting up enhanced Learning-to-Rank with improved features..."

# Enhanced feature store with better feature engineering
curl -X PUT "$SOLR_URL/$COLLECTION_NAME/schema/feature-store" \
  -H "Content-Type: application/json" \
  -d '{
    "store": "enhanced_features",
    "features": [
      {
        "name": "bm25_score",
        "class": "org.apache.solr.ltr.feature.SolrFeature",
        "params": {
          "q": "{!edismax qf=\"title^3 content\" v=\"${user_query}\"}"
        }
      },
      {
        "name": "vector_similarity",
        "class": "org.apache.solr.ltr.feature.SolrFeature",
        "params": {
          "q": "{!vectorSimilarity f=content_vector}${user_vector}"
        }
      },
      {
        "name": "title_exact_match",
        "class": "org.apache.solr.ltr.feature.SolrFeature",
        "params": {
          "q": "title:\"${user_query}\""
        }
      },
      {
        "name": "title_partial_match",
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
        "name": "content_length_normalized",
        "class": "org.apache.solr.ltr.feature.SolrFeature",
        "params": {
          "q": "{!func}log(content_length)"
        }
      },
      {
        "name": "recency_score",
        "class": "org.apache.solr.ltr.feature.SolrFeature",
        "params": {
          "q": "{!func}recip(ms(NOW,crawl_date),3.16e-11,1,1)"
        }
      },
      {
        "name": "url_depth",
        "class": "org.apache.solr.ltr.feature.SolrFeature",
        "params": {
          "q": "{!func}sub(8,depth)"
        }
      },
      {
        "name": "query_term_density",
        "class": "org.apache.solr.ltr.feature.SolrFeature",
        "params": {
          "q": "{!func}termfreq(content,\"${user_query}\")"
        }
      }
    ]
  }'

# Enhanced LambdaMART model with more sophisticated tree structure
curl -X PUT "$SOLR_URL/$COLLECTION_NAME/schema/model-store" \
  -H "Content-Type: application/json" \
  -d '{
    "store": "enhanced_model",
    "class": "org.apache.solr.ltr.model.LambdaMARTModel",
    "name": "enhanced_hybrid_ranker",
    "features": [
      {"name": "bm25_score"},
      {"name": "vector_similarity"},
      {"name": "title_exact_match"},
      {"name": "title_partial_match"},
      {"name": "domain_authority"},
      {"name": "content_length_normalized"},
      {"name": "recency_score"},
      {"name": "url_depth"},
      {"name": "query_term_density"}
    ],
    "params": {
      "trees": [
        {
          "weight": 1.5,
          "root": {
            "feature": "title_exact_match",
            "threshold": 0.1,
            "left": {
              "feature": "bm25_score",
              "threshold": 0.5,
              "left": {"value": 0.2},
              "right": {
                "feature": "vector_similarity",
                "threshold": 0.7,
                "left": {"value": 0.6},
                "right": {"value": 1.0}
              }
            },
            "right": {"value": 1.2}
          }
        },
        {
          "weight": 1.0,
          "root": {
            "feature": "vector_similarity",
            "threshold": 0.8,
            "left": {
              "feature": "title_partial_match",
              "threshold": 0.1,
              "left": {"value": 0.3},
              "right": {"value": 0.5}
            },
            "right": {
              "feature": "domain_authority",
              "threshold": 0.7,
              "left": {"value": 0.8},
              "right": {"value": 1.1}
            }
          }
        },
        {
          "weight": 0.8,
          "root": {
            "feature": "content_length_normalized",
            "threshold": 5.0,
            "left": {"value": 0.1},
            "right": {
              "feature": "query_term_density",
              "threshold": 2.0,
              "left": {"value": 0.4},
              "right": {"value": 0.7}
            }
          }
        },
        {
          "weight": 0.6,
          "root": {
            "feature": "recency_score",
            "threshold": 0.5,
            "left": {"value": 0.2},
            "right": {
              "feature": "url_depth",
              "threshold": 5.0,
              "left": {"value": 0.3},
              "right": {"value": 0.5}
            }
          }
        }
      ]
    }
  }'

echo "✅ Enhanced LTR setup complete!"
echo ""
echo "🎯 New features added:"
echo "   • Enhanced title matching (exact + partial)"
echo "   • Normalized content length scoring"
echo "   • URL depth consideration"
echo "   • Query term density analysis"
echo "   • More sophisticated tree structure"

# Test the enhanced model
echo ""
echo "🧪 Testing enhanced model..."
curl -s "$SOLR_URL/$COLLECTION_NAME/select" \
  -d "q=machine learning&defType=edismax&qf=title^3 content&rq={!ltr model=enhanced_hybrid_ranker reRankDocs=20}&rows=3&fl=id,title,score,[features]" | \
  jq '.response.docs[]?.title // "No results yet - run make real-scrape first"'
