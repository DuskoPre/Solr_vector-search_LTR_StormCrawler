package com.custom;

import com.digitalpebble.stormcrawler.ConfigurableTopology;
import com.digitalpebble.stormcrawler.Constants;
import com.digitalpebble.stormcrawler.bolt.*;
import com.digitalpebble.stormcrawler.indexing.solr.SolrIndexer;
import com.digitalpebble.stormcrawler.parse.ParseResult;
import com.digitalpebble.stormcrawler.parse.ParserBolt;
import com.digitalpebble.stormcrawler.persistence.redis.RedisSpout;
import com.digitalpebble.stormcrawler.util.ConfUtils;
import org.apache.storm.Config;
import org.apache.storm.LocalCluster;
import org.apache.storm.StormSubmitter;
import org.apache.storm.topology.TopologyBuilder;
import org.apache.storm.tuple.Fields;

/**
 * Custom StormCrawler topology that integrates with embedding service
 * to generate vectors for all crawled content using all-MiniLM-L6-v2
 */
public class SolrCrawlerWithEmbeddings extends ConfigurableTopology {

    public static void main(String[] args) throws Exception {
        ConfigurableTopology.start(new SolrCrawlerWithEmbeddings(), args);
    }

    @Override
    protected int run(String[] args) {
        TopologyBuilder builder = new TopologyBuilder();

        // URL spout from Redis queue
        builder.setSpout("urls", new RedisSpout(), 1);

        // Fetch web pages
        builder.setBolt("fetch", new FetcherBolt(), 10)
                .shuffleGrouping("urls");

        // Parse content with Tika
        builder.setBolt("parse", new ParserBolt(), 10)
                .localOrShuffleGrouping("fetch");

        // Custom bolt to generate embeddings
        builder.setBolt("embeddings", new EmbeddingBolt(), 5)
                .localOrShuffleGrouping("parse");

        // Index into Solr with vectors
        builder.setBolt("indexer", new SolrIndexer(), 5)
                .localOrShuffleGrouping("embeddings");

        // URL filtering and status updates
        builder.setBolt("status", new StatusUpdaterBolt(), 2)
                .localOrShuffleGrouping("fetch", Constants.StatusStreamName)
                .localOrShuffleGrouping("parse", Constants.StatusStreamName)
                .localOrShuffleGrouping("embeddings", Constants.StatusStreamName)
                .localOrShuffleGrouping("indexer", Constants.StatusStreamName);

        conf.setDebug(false);
        conf.setNumWorkers(4);
        conf.setMaxSpoutPending(100);

        String name = "hybrid-crawler-topology";
        if (isLocal) {
            LocalCluster cluster = new LocalCluster();
            cluster.submitTopology(name, conf, builder.createTopology());
        } else {
            StormSubmitter.submitTopology(name, conf, builder.createTopology());
        }
        return 0;
    }
}
