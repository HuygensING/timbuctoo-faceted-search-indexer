require 'net/http'
require 'json'
require_relative './http_client'

class Dataset
  attr_reader :metadata, :name, :is_published

  def initialize(name: nil, metadata: nil, label: nil, vreMetadata: nil, isPublished: nil)
    @client = HttpClient.new("http://example.com", nil)
    @name = name
    @metadata = fetch_metadata(metadata) if isPublished
    @is_published = isPublished
  end

  private
  def fetch_metadata(metadata_url)
    uri = URI.new(metadata_url)
    uri.query = URI.encode_www_form([["withCollectionInfo", "true"]] + URI.decode_www_form(uri.query))
    response = @client.send_http(HTTP::Get.new(uri), true, ['200'])

    JSON.parse(response.body, :symbolize_names => true)
  end
end

class TimbuctooIO
  # @param [String] base_url the timbuctoo server base url
  # @params [Boolean] dump_files flag for dumping files
  # @params [String] dump_dir the directory to dump the files in
  def initialize (base_url, dump_files: false, dump_dir: './')
    @client = HttpClient.new(base_url, nil)
    @dump_files = dump_files
    @dump_dir = dump_dir || './'
  end

  # Scrapes an entire Timbuctoo collection
  # @param [String] collection_name the name of the timbuctoo collection
  # @param [lambda] process_record the function to invoke for each single record in the batch
  # @param [Boolean] with_relations also scrape the direct relations of the records
  # @param [Integer] batch_size number of records per batch
  # @param [Boolean] from_file read from local file in stead of from http if the file is present
  def scrape_collection (collection_name,
                         process_record: lambda {|record| puts record.inspect },
                         with_relations: false,
                         batch_size: 100,
                         from_file: false,
                         debug_sample: false)

    start_value = 0
    data = nil
    while data.nil? or data.length > 0
      json_data = nil
      json_data = get_file_batch(batch_size, collection_name, start_value, with_relations) if from_file
      json_data = get_http_batch(batch_size, collection_name, start_value, with_relations) if json_data.nil?

      dump_to_file(collection_name, batch_size, start_value, with_relations, json_data) if @dump_files

      data = JSON.parse(json_data)

      data.each {|record| process_record.call(record) }

      start_value = start_value + batch_size
      break if debug_sample
    end
  end

  def fetch_datasets
    response = @client.send_http(Net::HTTP::Get.new(@client.make_uri("/v2.1/system/vres")), true, ['200'])

    JSON.parse(response.body, :symbolize_names => true)
        .map{|dataset_data| Dataset.new(dataset_data)}
        .select{|dataset_data| dataset_data.is_published}
  end


  private
  def get_file_batch(batch_size, collection_name, start_value, with_relations)
    filename = get_dump_filename(batch_size, collection_name, start_value, with_relations)
    return File.read filename if File.exists? filename
    nil
  end

  def get_http_batch(batch_size, collection_name, start_value, with_relations)
    response = @client.send_http(Net::HTTP::Get.new(@client.make_uri("/v2.1/domain/#{collection_name}", [
      ["rows", batch_size],
      ["start", start_value]
    ] + (with_relations ? [["withRelations", "true"]] : []))), true, ['200'])

    response.body
  end

  def dump_to_file (collection_name, batch_size, start_value, with_relations, response_body)
    filename = get_dump_filename(batch_size, collection_name, start_value, with_relations)
    File.open(filename, 'w') { |file| file.write(response_body) }
  end

  def get_dump_filename(batch_size, collection_name, start_value, with_relations)
    "#{@dump_dir.sub(/\/$/, '')}/" +
        "#{collection_name}_rows_#{batch_size}_start_#{start_value}" +
        "#{with_relations ? '_with_relations' : ''}.json"
  end

end