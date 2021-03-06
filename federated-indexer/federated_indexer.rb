require 'json'
require 'pp'
require_relative '../lib/mixins/converters/to_year_converter'
require_relative '../lib/mixins/converters/to_names_converter'
require_relative '../lib/timbuctoo_solr/default_mapper'
require_relative '../lib/timbuctoo_solr/timbuctoo_io'
require_relative '../lib/timbuctoo_solr/solr_io'

require_relative './archetype_config.rb'
require_relative './federated_mapper.rb'
require_relative './solr_updater.rb'


class FederatedIndexer

  def initialize(options)
    @solr_io = SolrIO.new(options[:solr_url], :authorization => options[:solr_auth])
    @timbuctoo_io = TimbuctooIO.new(options[:timbuctoo_url])
    @index_name = "aggregated"
    @forked = options[:forked]
    @debug_sample = options[:debug_sample]
  end

  def run
    start = Time.now
    initialize_index

    # fetches all datasets from vres endpoint (returned as class instance of timbuctoo_io database)
    datasets = @timbuctoo_io.fetch_datasets

    # generates configurations per archetype
    archetype_configs = datasets.select{|dataset| dataset.name.eql?("Admin")}.first
      .metadata.map{|_, collection| ArchetypeConfig.new(collection[:archetypeName], collection[:properties])}

    forks = []

    # loop through all the datasets which are not an archetype.
    datasets.reject{|dataset| dataset.name.eql?("Admin") or dataset.name.eql?("Base")}.each do |dataset|
      dataset.metadata.each do |_, collection|
        # skip scrape for relation collections
        next if collection[:relationCollection] or collection[:unknown]
        if @forked
          forks << Process.fork do
            collection_start = Time.now
            process_collection(archetype_configs, collection, dataset)
            puts "#{collection[:collectionName]} took #{Time.now - collection_start} seconds"
          end
        else
          collection_start = Time.now
          process_collection(archetype_configs, collection, dataset)
          puts "#{collection[:collectionName]} took #{Time.now - collection_start} seconds"
        end
      end
    end

    forks.each do |pid|
      Process.wait(pid)
    end

    @solr_io.commit(@index_name)
    puts "Total time #{Time.now - start} seconds"
  end

  private
  def initialize_index
    @solr_io.create(@index_name)

    @solr_io.delete_data(@index_name)
  end

  def process_collection(archetype_configs, collection, dataset)
    # Determine the correct configuration based on this collection's archetype
    archetype_config = archetype_configs.select { |conf| conf.name.eql?(collection[:archetypeName]) }.first

    # Initializes a mapper for this specific collection, based on the configuration for the archetype
    # it extends
    mapper = FederatedMapper.new(collection[:collectionName], collection[:archetypeName], dataset.name, archetype_config.get)

    # separate instance of solr updater isolates batches thread-safely
    solr_updater = SolrUpdater.new(@index_name, @solr_io, mapper)

    # scrapes the collection and sends each record to the updater
    @timbuctoo_io.scrape_collection(collection[:collectionName],
                                    :with_relations => true,
                                    :debug_sample => @debug_sample,
                                    :process_record => -> (record) { solr_updater.add(record) })
    # indexes the remaining batch
    solr_updater.flush
  end
end