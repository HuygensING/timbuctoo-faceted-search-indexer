require_relative '../lib/mixins/converters/to_year_converter'
require_relative '../lib/mixins/converters/to_names_converter'
require_relative '../lib/timbuctoo_solr/default_mapper'
require_relative '../lib/timbuctoo_solr/timbuctoo_io'
require_relative '../lib/timbuctoo_solr/solr_io'
require_relative '../lib/timbuctoo_solr/import_status'
require_relative './generic_configs'

class GenericMapper < DefaultMapper
  include ToYearConverter
  include ToNamesConverter

  def convert_value(input_value, type)
    begin
      return super(input_value, type)
    rescue Exception => e
      puts "convert error: #{e.inspect}"
      return nil
    end
  end
end

class GenericIndexer

  def initialize(options)
    @mappers = {}
    @solr_io = SolrIO.new(options[:solr_url], :authorization => options[:solr_auth])
    @import_status = ImportStatus.new(options[:solr_url], "monitor", options[:vre_id], :authorization => options[:solr_auth])
    GenericConfigs.new(:vre_id => options[:vre_id], :timbuctoo_url => options[:timbuctoo_url]).fetch.each do |config|
      @mappers[config[:collection]] = GenericMapper.new(:properties => config[:properties], :relations => config[:relations])
    end

    @timbuctoo_io = TimbuctooIO.new(options[:timbuctoo_url])
  end

  def run
    start_time = Time.new
    indexer_succeeded = false
    commited_indexes = []
    @import_status.start_import(@mappers.keys)
    @mappers.each do |collection, mapper|
      @solr_io.create(collection)
      @solr_io.delete_data(collection)
      begin
        count_records = 0
        @timbuctoo_io.scrape_collection(collection, :with_relations => true, :process_record => -> (record) {
          convert(mapper, record, collection)
          count_records += 1
          if (Time.new - start_time) > 1
            STDERR.puts "#{collection}: #{count_records} converted"
            @import_status.update_progress(collection, count_records)
            start_time = Time.new
          end
        })

        commited_indexes << collection
        @solr_io.commit(collection)
        STDERR.puts "#{collection}: #{count_records} indexed"
        @import_status.update_progress(collection, count_records, true)
        indexer_succeeded = true
      rescue Exception => e
        STDERR.puts "indexer failed (see stack trace below)"
        STDERR.puts "Error during processing: #{$!}"
        STDERR.puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
        indexer_succeeded = false
        break
      end
    end
    if !indexer_succeeded
      commited_indexes.each do |collection|
        @solr_io.delete_index(collection)
      end
    end
    @import_status.finish_import(indexer_succeeded)
  end

  def convert(mapper, record, collection)
    @solr_io.update(collection, [mapper.convert(record)])
  end
end
