package com.custom;

import com.digitalpebble.stormcrawler.Metadata;
import com.digitalpebble.stormcrawler.parse.ParseResult;
import com.digitalpebble.stormcrawler.util.ConfUtils;
import org.apache.storm.task.OutputCollector;
import org.apache.storm.task.TopologyContext;
import org.apache.storm.topology.OutputFieldsDeclarer;
import org.apache.storm.topology.base.BaseRichBolt;
import org.apache.storm.tuple.Fields;
import org.apache.storm.tuple.Tuple;
import org.apache.storm.tuple.Values;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Map;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.JsonNode;

/**
 * Bolt that generates vector embeddings using all-MiniLM-L6-v2
 * for parsed web content before indexing into Solr
 */
public class EmbeddingBolt extends BaseRichBolt {
    
    private static final Logger LOG = LoggerFactory.getLogger(EmbeddingBolt.class);
    private OutputCollector collector;
    private HttpClient httpClient;
    private String embeddingServiceUrl;
    private ObjectMapper objectMapper;
    
    @Override
    public void prepare(Map conf, TopologyContext context, OutputCollector collector) {
        this.collector = collector;
        this.httpClient = HttpClient.newHttpClient();
        this.objectMapper = new ObjectMapper();
        
        // Get embedding service URL from config
        this.embeddingServiceUrl = ConfUtils.getString(conf, "embedding.service.url", 
                                                     "http://embedding-service:8080");
        
        LOG.info("EmbeddingBolt initialized with service URL: {}", embeddingServiceUrl);
    }
    
    @Override
    public void execute(Tuple tuple) {
        String url = tuple.getStringByField("url");
        byte[] content = tuple.getBinaryByField("content");
        Metadata metadata = (Metadata) tuple.getValueByField("metadata");
        
        try {
            // Extract text content for embedding
            String textContent = extractTextContent(content, metadata);
            
            if (textContent == null || textContent.trim().isEmpty()) {
                LOG.warn("No text content found for URL: {}", url);
                collector.emit(tuple, new Values(url, content, metadata));
                collector.ack(tuple);
                return;
            }
            
            // Generate vector embedding using all-MiniLM-L6-v2
            double[] embedding = generateEmbedding(textContent);
            
            if (embedding != null) {
                // Add vector to metadata for Solr indexing
                metadata.addValue("content_vector", arrayToString(embedding));
                LOG.info("Generated embedding for URL: {} (dimension: {})", url, embedding.length);
            }
            
            collector.emit(tuple, new Values(url, content, metadata));
            collector.ack(tuple);
            
        } catch (Exception e) {
            LOG.error("Error processing embedding for URL: " + url, e);
            collector.fail(tuple);
        }
    }
    
    private String extractTextContent(byte[] content, Metadata metadata) {
        // Get parsed text from metadata (set by ParserBolt/Tika)
        String[] textValues = metadata.getValues("text");
        if (textValues != null && textValues.length > 0) {
            return textValues[0];
        }
        
        // Fallback to content if available
        if (content != null && content.length > 0) {
            return new String(content).replaceAll("<[^>]+>", ""); // Basic HTML strip
        }
        
        return null;
    }
    
    private double[] generateEmbedding(String text) {
        try {
            // Prepare request to embedding service
            String requestBody = objectMapper.writeValueAsString(
                Map.of("text", text.substring(0, Math.min(text.length(), 5000))) // Limit text length
            );
            
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(embeddingServiceUrl + "/encode"))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                    .build();
            
            // Send request and get response
            HttpResponse<String> response = httpClient.send(request, 
                    HttpResponse.BodyHandlers.ofString());
            
            if (response.statusCode() == 200) {
                JsonNode jsonResponse = objectMapper.readTree(response.body());
                JsonNode embeddingNode = jsonResponse.get("embedding");
                
                // Convert JsonNode array to double array
                double[] embedding = new double[embeddingNode.size()];
                for (int i = 0; i < embeddingNode.size(); i++) {
                    embedding[i] = embeddingNode.get(i).asDouble();
                }
                
                return embedding;
            } else {
                LOG.error("Embedding service returned status: {} for text length: {}", 
                         response.statusCode(), text.length());
            }
            
        } catch (IOException | InterruptedException e) {
            LOG.error("Error calling embedding service", e);
        }
        
        return null;
    }
    
    private String arrayToString(double[] array) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < array.length; i++) {
            if (i > 0) sb.append(",");
            sb.append(array[i]);
        }
        sb.append("]");
        return sb.toString();
    }
    
    @Override
    public void declareOutputFields(OutputFieldsDeclarer declarer) {
        declarer.declare(new Fields("url", "content", "metadata"));
    }
}

# URL filters
urlfilters:
  - class: "com.digitalpebble.stormcrawler.filtering.basic.BasicURLFilter"
    name: "basicURLFilter"
    params:
      maxPathRepetition: 3
      maxLength: 1024
  
  - class: "com.digitalpebble.stormcrawler.filtering.regex.RegexURLFilter"
    name: "regexURLFilter"
    params:
      regexFilterFile: "regex-urlfilter.txt"

# Parse filters
parsefilters:
  - class: "com.digitalpebble.stormcrawler.parse.filter.ContentFilter"
    name: "contentFilter"
    params:
      pattern: "(?i)\\b(the|and|or|but|in|on|at|to|for|of|with|by)\\b"
      
  - class: "com.digitalpebble.stormcrawler.parse.filter.LinkParseFilter"
    name: "linkParseFilter"
    params:
      # Extract outlinks for further crawling
      pattern: "(?i)^https?://"
