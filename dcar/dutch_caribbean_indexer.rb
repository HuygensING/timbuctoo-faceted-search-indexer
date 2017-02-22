require_relative '../lib/timbuctoo_solr/timbuctoo_io'
require_relative '../lib/timbuctoo_solr/solr_io'

require_relative './configs/dcar_archive_config'
require_relative './configs/dcar_archiver_config'
require_relative './configs/dcar_legislation_config'
require_relative './dcar_mapper'
require_relative '../lib/timbuctoo_solr/import_status'

class DutchCaribbeanIndexer
  def initialize(options)
    @options = options

    @mappers = {
      :dcararchives => DcarMapper.new(DcarArchiveConfig.get),
      :dcarlegislations => DcarMapper.new(DcarLegislationConfig.get),
      :dcararchivers => DcarMapper.new(DcarArchiverConfig.get)
    }

    @timbuctoo_io = TimbuctooIO.new(options[:timbuctoo_url], {
        :dump_files => options[:dump_files],
        :dump_dir => options[:dump_dir],
    })

    @solr_io = SolrIO.new(options[:solr_url], {:authorization => options[:solr_auth]})
    @import_status = ImportStatus.new(options[:solr_url], "monitor", "DutchCaribbean", :authorization => options[:solr_auth])
  end

  def run
    indexer_succeeded = false
    begin
      @import_status.start_import(["dcararchives", "dcararchivers", "dcarlegislations"])
      reindex("dcararchives")
      reindex("dcararchivers")
      reindex("dcarlegislations")
      indexer_succeeded = true
    ensure
      @import_status.finish_import(indexer_succeeded)
    end
  end

  private

  def reindex(collection_name)
    create_index(collection_name)
    puts "DELETE #{collection_name}"
    @solr_io.delete_data(collection_name)
    puts "UPDATE #{collection_name}"
    batch = []
    batch_size = 1000
    count_records = 0
    @timbuctoo_io.scrape_collection(collection_name, {
        :process_record => -> (record) {
          batch << @mappers[collection_name.to_sym].convert(record)
          count_records = count_records + 1
          if batch.length >= batch_size
            @solr_io.update(collection_name, batch)
            @import_status.update_progress(collection_name, count_records)
            batch = []
          end
        },
        :with_relations => true,
        :from_file => @options[:from_file],
        :batch_size => 1000
    })
    @solr_io.update(collection_name, batch)
    puts "COMMIT #{collection_name}"
    @solr_io.commit(collection_name)
    @import_status.update_progress(collection_name, count_records, true)
  end

  def create_index collection
    puts "CREATE #{collection}"
    @solr_io.create(collection)
  end
end
