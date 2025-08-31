from flask import Flask, request, jsonify
from sentence_transformers import SentenceTransformer
import numpy as np
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Load the all-MiniLM-L6-v2 model (384 dimensions)
print("Loading all-MiniLM-L6-v2 model...")
model = SentenceTransformer('all-MiniLM-L6-v2')
print("Model loaded successfully!")

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({"status": "healthy", "model": "all-MiniLM-L6-v2"})

@app.route('/encode', methods=['POST'])
def encode_text():
    try:
        data = request.get_json()
        text = data.get('text', '')
        
        if not text:
            return jsonify({"error": "No text provided"}), 400
        
        # Generate embedding using all-MiniLM-L6-v2
        embedding = model.encode([text])[0]
        
        # Convert to list for JSON serialization
        embedding_list = embedding.tolist()
        
        return jsonify({
            "embedding": embedding_list,
            "dimension": len(embedding_list),
            "model": "all-MiniLM-L6-v2"
        })
    
    except Exception as e:
        app.logger.error(f"Error encoding text: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/encode_batch', methods=['POST'])
def encode_batch():
    try:
        data = request.get_json()
        texts = data.get('texts', [])
        
        if not texts:
            return jsonify({"error": "No texts provided"}), 400
        
        # Generate embeddings for batch
        embeddings = model.encode(texts)
        
        # Convert to lists
        embeddings_list = [emb.tolist() for emb in embeddings]
        
        return jsonify({
            "embeddings": embeddings_list,
            "count": len(embeddings_list),
            "dimension": len(embeddings_list[0]) if embeddings_list else 0,
            "model": "all-MiniLM-L6-v2"
        })
    
    except Exception as e:
        app.logger.error(f"Error encoding batch: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
