# File: scripts/enhanced-seed-with-real-scraping.sh
#!/usr/bin/env bash
set -euo pipefail

# --- configurable ---
SOLR_URL="${SOLR_URL:-http://localhost:8983/solr}"
COLLECTION_NAME="${COLLECTION_NAME:-hybrid_search}"
SOLR_UPDATE_URL="${SOLR_URL%/}/${COLLECTION_NAME}/update"
CONTENT_MAX_LEN="${CONTENT_MAX_LEN:-5000}"
MODEL_NAME="${MODEL_NAME:-sentence-transformers/all-MiniLM-L6-v2}"  # 384 dims
COMMIT="${COMMIT:-true}"   # set to "false" to buffer commits on Solr side
# ---------------------

echo "🌐 Setting up real web scraping with all-MiniLM-L6-v2 embeddings..."

# Function to scrape URL and generate embedding, then index to Solr
scrape_and_index() {
    local url="${1:-}"
    if [[ -z "$url" ]]; then
        echo "Usage: scrape_and_index <url>" >&2
        return 2
    fi

    local doc_id
    doc_id="$(echo "$url" | sed 's/[^a-zA-Z0-9]/_/g')"
    echo "📄 Scraping: $url"

    # 1) Fetch HTML (follow redirects, sensible UA)
    local html
    if ! html="$(curl -fsSL -A "Mozilla/5.0 (compatible; EmbedBot/1.0)" "$url")"; then
        echo "❌ Failed to fetch: $url" >&2
        return 1
    fi

    # 2) Extract readable text + title; truncate to $CONTENT_MAX_LEN
    #    (Uses BeautifulSoup; strips scripts/styles/etc.)
    #    Outputs JSON with keys: content, title, domain
    local extracted_json
    if ! extracted_json="$(
python3 - "$url" "$CONTENT_MAX_LEN" << 'PY'
import sys, json
from urllib.parse import urlparse
from bs4 import BeautifulSoup

url = sys.argv[1]
maxlen = int(sys.argv[2])
html = sys.stdin.read()

soup = BeautifulSoup(html, "html.parser")
for tag in soup(["script","style","noscript","template","svg","nav","footer","header","form","iframe"]):
    tag.decompose()

title = ""
if soup.title and soup.title.string:
    title = soup.title.string.strip()

text = " ".join(x.strip() for x in soup.stripped_strings)
if len(text) > maxlen:
    text = text[:maxlen]

domain = urlparse(url).netloc

print(json.dumps({"content": text, "title": title, "domain": domain}, ensure_ascii=False))
PY
    <<<"$html"
    )"; then
        echo "❌ Failed to parse HTML for: $url" >&2
        return 1
    fi

    # 3) Build embedding with sentence-transformers (384 dims)
    #    We embed content if present; otherwise fall back to title/url.
    local embedding_json
    if ! embedding_json="$(
python3 - "$MODEL_NAME" << 'PY'
import sys, json
from sentence_transformers import SentenceTransformer

model_name = sys.argv[1]
payload = json.load(sys.stdin)

text = payload.get("content") or payload.get("title") or payload.get("url") or ""
model = SentenceTransformer(model_name)
vec = model.encode(text, normalize_embeddings=True).tolist()
payload["content_vector"] = vec
print(json.dumps(payload, ensure_ascii=False))
PY
    <<<"$(jq -c --arg url "$url" '. + {url: $url}' <<<"$extracted_json")"
    )"; then
        echo "❌ Failed to generate embedding for: $url" >&2
        return 1
    fi

    # 4) Assemble final Solr doc JSON safely in Python (handles all escaping)
    local solr_doc
    if ! solr_doc="$(
python3 - "$doc_id" << 'PY'
import sys, json
from datetime import datetime, timezone

doc_id = sys.argv[1]
payload = json.load(sys.stdin)

doc = {
    "id": doc_id,
    "url": payload["url"],
    "content": payload.get("content",""),
    "title": payload.get("title",""),
    "domain": payload.get("domain",""),
    "crawl_date": datetime.now(timezone.utc).isoformat(),
    "content_vector": payload["content_vector"],  # float[384]
}
print(json.dumps(doc, ensure_ascii=False))
PY
    <<<"$embedding_json"
    )"; then
        echo "❌ Failed to assemble Solr document for: $url" >&2
        return 1
    fi

    # 5) Send to Solr JSON update endpoint
    #    NOTE: Your Solr schema must define a 384-dim dense vector field `content_vector`.
    if ! curl -fsS -X POST \
        -H "Content-Type: application/json" \
        --data "[$solr_doc]" \
        "${SOLR_UPDATE_URL}?commit=${COMMIT}"; then
        echo "❌ Solr update failed for: $url" >&2
        return 1
    fi

    echo "✅ Indexed id=${doc_id}"
}

# --- optional: seed a few pages ---
# scrape_and_index "https://example.com/"
# scrape_and_index "https://solr.apache.org/"
# scrape_and_index "https://en.wikipedia.org/wiki/Solr"
