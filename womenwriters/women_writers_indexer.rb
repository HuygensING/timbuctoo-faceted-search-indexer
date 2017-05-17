require_relative '../lib/timbuctoo_solr/timbuctoo_io'
require_relative '../lib/timbuctoo_solr/solr_io'
require_relative '../lib/timbuctoo_solr/default_mapper'

require_relative './configs/ww_collective_config'
require_relative './configs/ww_person_config'
require_relative './configs/ww_document_config'
require_relative './mappers/ww_person_mapper'
require_relative './mappers/ww_document_mapper'
require_relative './mappers/ww_person_reception_mapper'
require_relative './mappers/ww_document_reception_mapper'
require_relative '../lib/timbuctoo_solr/import_status'

class WomenWritersIndexer
  def initialize(options)
    @options = options

    @person_mapper = WwPersonMapper.new(WwPersonConfig.get)
    @document_mapper = WwDocumentMapper.new(WwDocumentConfig.get)
    @collective_mapper = DefaultMapper.new(WwCollectiveConfig.get)

    @person_reception_mapper = WwPersonReceptionMapper.new(@person_mapper, @document_mapper)
    @document_reception_mapper = WwDocumentReceptionMapper.new(@document_mapper)

    @timbuctoo_io = TimbuctooIO.new(options[:timbuctoo_url], {
        :dump_files => options[:dump_files],
        :dump_dir => options[:dump_dir],
    })

    @solr_io = SolrIO.new(options[:solr_url], {:authorization => options[:solr_auth]})
    @import_status = ImportStatus.new(options[:solr_url], "monitor", "WomenWriters", :authorization => options[:solr_auth])

  end

  def run
    indexer_succeeded = false
    begin
      @import_status.start_import(["wwcollectives", "wwpersons", "wwdocuments", "wwpersonreceptions", "wwdocumentreceptions"])
      # Scrape persons and documents from Timbuctoo
      scrape_persons
      scrape_documents

      # Always run person_mapper.add_languages before @document_mapper.add_creators to ensure correct _childDocuments_
      # filters on wwdocuments index and wwdocumentreceptions index!!
      @person_mapper.add_languages(@document_mapper)
      @document_mapper.add_creators(@person_mapper)


      puts "Found #{@document_mapper.person_receptions.length} person receptions"
      puts "Found #{@document_mapper.document_receptions.length} document receptions"

      reindex_collectives
      reindex_persons
      reindex_documents
      reindex_person_receptions
      reindex_document_receptions
    ensure
      @import_status.finish_import(indexer_succeeded)
    end
  end

  private

  def scrape_documents
    @timbuctoo_io.scrape_collection("wwdocuments", {
        :with_relations => true,
        :from_file => @options[:from_file],
        :process_record => @document_mapper.method(:convert)
    })
    puts "SCRAPE: #{@document_mapper.record_count} documents"
  end

  def scrape_persons
    @timbuctoo_io.scrape_collection("wwpersons", {
        :with_relations => true,
        :from_file => @options[:from_file],
        :process_record => @person_mapper.method(:convert)
    })
    puts "SCRAPE: #{@person_mapper.record_count} persons"
  end

  def reindex_collectives
    @solr_io.create("wwcollectives")
    @solr_io.delete_data("wwcollectives")
    batch = []
    batch_size = 500
    @timbuctoo_io.scrape_collection("wwcollectives", {
        :process_record => -> (record) {
          batch << @collective_mapper.convert(record)
          if batch.length >= batch_size
            @solr_io.update("wwcollectives", batch)
            batch = []
          end
        },
        :from_file => @options[:from_file]
    })
    @solr_io.update("wwcollectives", batch)
    puts "COMMIT collectives"
    @solr_io.commit("wwcollectives")
  end

  def reindex_persons
    @solr_io.create("wwpersons")
    @solr_io.delete_data("wwpersons")
    @person_mapper.send_cached_batches_to("wwpersons", @solr_io.method(:update))
    @solr_io.commit("wwpersons")
  end

  def reindex_documents
    @solr_io.create("wwdocuments")
    @solr_io.delete_data("wwdocuments")
    @document_mapper.send_cached_batches_to("wwdocuments", @solr_io.method(:update))
    @solr_io.commit("wwdocuments")
  end

  def reindex_person_receptions
    @solr_io.create("wwpersonreceptions")
    @solr_io.delete_data("wwpersonreceptions")
    update_reception_index(@person_reception_mapper, "wwpersonreceptions", :person_receptions)
    @solr_io.commit("wwpersonreceptions")
  end

  def reindex_document_receptions
    @solr_io.create("wwdocumentreceptions")
    @solr_io.delete_data("wwdocumentreceptions")
    update_reception_index(@document_reception_mapper, "wwdocumentreceptions", :document_receptions)
    @solr_io.commit("wwdocumentreceptions")
  end

  def update_reception_index(reception_mapper, index_name, reception_entry)
    batch = []
    batch_size = 500
    @document_mapper.send(reception_entry).each do |reception|
      converted = reception_mapper.convert(reception)
      if converted != nil
        batch << reception_mapper.convert(reception)
        if batch.length >= batch_size
          @solr_io.update(index_name, batch)
          batch = []
        end
      end
    end
    @solr_io.update(index_name, batch)
  end
end
