require 'json'
require_relative './http_client'

class SolrIO
  # @param [String] base_url the solr base_url (usually including /solr)
  # @param [String] authorization the authorization header
  def initialize(base_url, authorization = nil)
    @client = HttpClient.new(base_url, authorization)
  end

  # Creates a new solr index
  # @param [String] index_name name of the index
  # @param [String] config_set the config set used
  def create(index_name, config_set: 'data_driven_schema_configs')
    checkresponse = @client.send_http(HTTP::Get.new(@client.make_uri("/#{index_name}/select")), true, ['200', '404'])
    if checkresponse.code.eql?('404')
      uri = @client.make_uri('/admin/cores', [
        ["action", "CREATE"],
        ["name", index_name],
        ["instanceDir", "mycores/" + index_name],
        ["configSet", config_set]
      ])
      response = @client.send_http(HTTP::Post.new(uri), true, ['200', '500'])
      if response.code.eql?('500') && !response.body.include?("Core with name '#{index_name}' already exists.")
        raise "Create index failed in an unexpected way: \n\n#{response.body}"
      end
    end
  end

  # Sends an update request with a payload to solr index (without commit)
  # @param [String] index_name name of the index
  # @param [Hash|Array] payload the Json serializable payload
  def update(index_name, payload)
    uri = @client.make_uri("/#{index_name}/update/")
    req = HTTP::Post.new(uri)
    req.content_type = "application/json"
    req.body = payload.to_json
    @client.send_http(req, true, ['200'])
  end

  # Sends a commit request to solr
  # @param [String] index_name name of the index
  def commit(index_name)
    uri = @client.make_uri("/#{index_name}/update/", [["commit", "true"]])
    req = HTTP::Post.new(uri)
    response = @client.send_http(req, true, ['200'])
  end

  # Deletes all contents of a solr index
  # @param [String] index_name name of the index
  def delete_data(index_name)
    uri = @client.make_uri("/#{index_name}/update/")
    req = HTTP::Post.new(uri)
    req.content_type = 'text/xml'
    req.body = '<delete><query>*:*</query></delete>'
    response = @client.send_http(req, true, ['200'])
  end

  # Deletes an entire solr index
  # @param [String] index_name name of the index
  def delete_index(index_name)
    uri = @client.make_uri('/admin/cores', [
      ["action", "UNLOAD"],
      ["core", index_name],
      ["deleteInstanceDir", "true"]
    ])
    response = @client.send_http(HTTP::Post.new(uri), true, ['200'])
  end

end
