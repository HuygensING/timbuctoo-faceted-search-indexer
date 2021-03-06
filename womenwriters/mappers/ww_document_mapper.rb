require_relative '../../lib/timbuctoo_solr/default_mapper'
require_relative '../../lib/mixins/converters/to_year_converter'


class WwDocumentMapper < DefaultMapper
  include ToYearConverter

  attr_reader :cache, :record_count, :person_receptions, :document_receptions

  def initialize(options)
    super options
    @cache = {}
    @record_count = 0
    @person_receptions = []
    @document_receptions = []
  end

  def convert(record)
    data = super(record)
    data['type_s'] = 'document'
    add_english_title(data)
    add_location_sort(data)
    add_language_sort(data)

    add_document_receptions(record)
    add_person_receptions(record)

    puts "document scrape: #{@record_count}" if @record_count % 100 == 0
    @record_count += 1
    @cache[data['id']] = data
  end

  def add_creators(person_mapper)
    @cache.each do |id, record|
      @cache[id]['_childDocuments_'] = []
      name_sorts = Array.new
      @cache[id]['authorGender_ss'] = Array.new
      @cache[id]['authorName_ss'] = Array.new
      @cache[id]['authorNameSort_s'] = ''

      if record['@authorIds'] != nil
        record['@authorIds'].each do |author_id|
          author = person_mapper.find(author_id)
          if author.nil?
            $stderr.puts "WARNING Problem finding wwperson #{author_id} which isCreatorOf #{id} (wrong VRE?)"
          else
            child_author = {}
            author.each do |key, value|
              child_author["person_#{key}"] = value unless key.eql?("id")
            end
            child_author["id"] = "#{id}/#{author_id}"
            @cache[id]['authorGender_ss'] << author['gender_s']
            @cache[id]['authorName_ss'] << author['displayName_s']
            name_sorts << author['nameSort_s']
            @cache[id]['_childDocuments_'] << child_author
          end
        end
      end

      @cache[id]['authorNameSort_s'] = name_sorts.sort.first if name_sorts.length > 0
      @cache[id].delete('@authorIds')
    end
  end

  def find(id)
    @cache[id]
  end

  def send_cached_batches_to(index_name, batch_callback)
    batch_size = 500
    batch = []
    @cache.each do |key, record|
      batch << record
      if batch.length >= batch_size
        batch_callback.call(index_name, batch)
        batch = []
      end
    end
    batch_callback.call(index_name, batch)
  end

  private
  def add_location_sort(data)
    if data["publishLocation_ss"] != nil
      data["locationSort_s"] = data["publishLocation_ss"].sort.join(" ")
    end
  end

  def add_language_sort(data)
    if data["language_ss"] != nil
      data["languageSort_s"] = data["language_ss"].sort.join(" ")
    end
  end

  def add_english_title(data)
    unless data['^englishTitle'].nil?
      data['title_t'] = data['title_t'].nil? ? data['^englishTitle'] : "#{data['title_t']} #{data['^englishTitle']}"
      data.delete('^englishTitle')
    end
  end

  def add_person_receptions(record)
    unless record['@relations'].nil?
      WwDocumentMapper.person_reception_names.each do |rec_rel|
        unless record['@relations'][rec_rel].nil?
          record['@relations'][rec_rel].each do |rr_data|
            wanted_reception = Hash.new
            wanted_reception[:reception_id] = record['_id']
            wanted_reception[:person_id] = rr_data['id']
            wanted_reception[:relation_id] = rr_data['relationId']
            wanted_reception[:relationType] = rec_rel
            @person_receptions << wanted_reception
          end
        end
      end
    end
  end

  def add_document_receptions(record)
    unless record['@relations'].nil?
      WwDocumentMapper.document_reception_names.each do |rec_rel|
        unless record['@relations'][rec_rel].nil?
          record['@relations'][rec_rel].each do |rr_data|
            wanted_reception = Hash.new
            wanted_reception[:reception_id] = record['_id']
            wanted_reception[:document_id] = rr_data['id']
            wanted_reception[:relation_id] = rr_data['relationId']
            wanted_reception[:relationType] = rec_rel
            @document_receptions << wanted_reception
          end
        end
      end
    end
  end


  def WwDocumentMapper.person_reception_names
    [
        "isBiographyOf",
        "commentsOnPerson",
        "isDedicatedTo",
        "isAwardForPerson",
        "listsPerson",
        "mentionsPerson",
        "isObituaryOf",
        "quotesPerson",
        "referencesPerson"
    ]
  end

  def WwDocumentMapper.document_reception_names
    [
        "isEditionOf",
        "isSequelOf",
        "isTranslationOf",
        "isAdaptationOf",
        "isPlagiarismOf",
        "hasAnnotationsOn",
        "isBibliographyOf",
        "isCensoringOf",
        "commentsOnWork",
        "isAnthologyContaining",
        "isCopyOf",
        "isAwardForWork",
        "isPrefaceOf",
        "isIntertextualTo",
        "listsWork",
        "mentionsWork",
        "isParodyOf",
        "quotesWork",
        "referencesWork"
    ]
  end
end