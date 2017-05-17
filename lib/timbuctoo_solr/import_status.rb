require 'json'
require_relative './http_client'
require_relative './solr_io'
include Net
# require "fiber" #for testing

#                                                                         +-------------------+
#  +----------------+  start_import  +------------------+  finish_import  |  imported         |
#  |  non-existing  +----------------+  importing       +----------------->  ready: true      |
#  |                |                |  ready: false    |                 |  updating: false  |
#  +----------------+                |  updating: true  |                 |                   |
#                                    |                  |                 +--^----------------+
#                                    +------------------+                    |      |
#                                                               finish_import|      |start_import
#                                                                            |      |
#                                                                    +--------------v---+
#                                                                    |  re-import       |
#                                                                    |  ready: true     |
#                                                                    |  updating: true  |
#                                                                    |                  |
#                                                                    +------------------+

class ConcurrentSolrUpdateError < StandardError
end

class ServerContractError < StandardError
end


class ImportStatus

  # @param [String] base_url the solr base_url (usually including /solr)
  # @param [String] authorization the authorization header
  def initialize(base_url, index_name, vre_name, authorization = nil, pause = false)
    @client = HttpClient.new(base_url, authorization)
    @solr_io = SolrIO.new(base_url, authorization)
    @solr_io.create(index_name)
    @index_name = index_name
    @vre_name = vre_name
    @pause = pause
    @payload = {
      "id" => @vre_name
    }
  end

  #starts an import, or raises an exception if an import is already running
  def start_import(expected_indices)
    claim()
    for index in 0 ... expected_indices.size
      puts @payload["collection_count_" + expected_indices[index]] = 0
      puts @payload["collection_finished_" + expected_indices[index]] = false
    end
    @version = update_with_version(@index_name, @version, [@payload])
    @payload
  end

  #sets the current progress for an index
  def update_progress(collection_name, count, isCommitted = false)
    if !(@version > 0)
      STDERR.puts "No claim made!"
    else
      begin
        @payload["collection_count_" + collection_name] = count
        @payload["collection_finished_" + collection_name] = isCommitted
        @version = update_with_version(@index_name, @version, [@payload])
      rescue ResponseError => e
        if e.response.eql?("409")
          raise ConcurrentSolrUpdateError, "Our version is not the latest, maybe we already relinquished?"
        else
          raise
        end
      end
    end
  end

  #sets the progress for the indices in this vre
  def get_progress()
    doc = get_vre_status()
    result = {
      "updating" => false,
      "ready" => false
    }
    if doc
      doc.each {|key, value|
        if key.to_s().start_with?("collection_count_")
          outputkey = key["collection_count_".length..-1]
          subkey = "count"
        elsif key.to_s().start_with?("collection_finished_")
          outputkey = key["collection_finished_".length..-1]
          subkey = "finished"
        end
        if outputkey
          if !result.key?(outputkey)
            result[outputkey] = {}
          end
          result[outputkey][subkey] = value[0] if value
        end
      }
      if doc[:updating]
        result["updating"] = !!doc[:updating][0]
      else
        result["updating"] = false
      end
      if doc[:ready]
        result["updating"] = !!doc[:ready][0]
      else
        result["updating"] = false
      end
    end
    result
  end

  #marks an import as finished (idempotent, but logs if the import was never claimed. Throws if the import was claimed, but was still edited in the mean time)
  def finish_import(success)
    relinquish_claim(success)
  end

private
  def get_vre_status()
    uri = @client.make_uri("/#{@index_name}/select", [
      ["q", "id:" + @vre_name],
      ["wt", "json"]
    ])

    response = @client.send_http(Net::HTTP::Get.new(uri), true, ['200'])
    
    docs = JSON.parse(response.body, :symbolize_names => true)[:response][:docs]
    if docs.length > 0
      if docs.length > 1
        STDERR.puts("More then one document asserted for vre #{@vre_name} in #{@index_name}")
      end
      docs[0]
    end
  end

  def update_with_version(index_name, version, payload)
    uri = @client.make_uri("/#{index_name}/update/", [
      ["versions", "true"],
      ["_version_", version]
    ])

    req = HTTP::Post.new(uri)
    req.content_type = "application/json"
    req.body = payload.to_json
    response = @client.send_http(req, true, ['200'])
    @solr_io.commit(index_name)
    added = JSON.parse(response.body, :symbolize_names => true)[:adds]
    #adds is an array contiaining [id_of_doc, version_of_doc] if you update multiple documents at the same time
    #it will contain [id_of_doc_1, version_of_doc_1, id_of_doc_2, version_of_doc_2]
    if added.length != 2 #we only updated 1 id
      STDERR.puts "response body is not what we expect: " + response.body
      raise "Response body is not what we expect", ServerContractError
    else
      return added[1]
    end
  end

  def claim()
    if @version && @version > 0
      STDERR.puts "Claimed twice"
    else 
      doc = get_vre_status()
      #see if there was already a document for this vre
      if doc && doc[:updating] && doc[:updating][0]
        raise ConcurrentSolrUpdateError, "Document is already being updated"
      end
      if doc
        version = doc[:_version_]
      else
        version = -1 #A version of -1 indicates to solr that we expect the document to be absent. It wil return 409 if the document exists
      end

      # if @pause then Fiber.yield true end
      begin
        @payload["updating"] = true
        @version = update_with_version(@index_name, version, [@payload])
      rescue ResponseError => e
        if e.response.eql?("409")
          raise ConcurrentSolrUpdateError, "Someone else claimed this vre concurrently. In a rare case, this might have been this thread (The client sent a POST, the post arrived at solr but the response never arrived at the client, the client retries, solr sends a version conflict). Please check the logs to see if this might have been the case."
        else
          raise
        end
      end
    end
  end

  def relinquish_claim(success)
    if !@version || !(@version > 0)
      STDERR.puts "relinquising claim without ever acquiring one"
    else
      begin
        @payload["updating"] = false
        if (success)
          @payload["ready"] = true #If it wasn't a success, then an update will have been rolled back (so ready is still true) and an initial import will have been deleted (ready is still false)
        end
        update_with_version(@index_name, @version, [@payload])
        @version = nil
      rescue ResponseError => e
        if e.response.eql?("409")
          raise ConcurrentSolrUpdateError, "Our version is not the latest, maybe we already relinquished?"
        else
          raise
        end
      end
    end
  end
end

# solr_io = SolrIO.new("http://localhost:8081/solr", nil)
# solr_io.delete_index("monitortest")

# threadA = Fiber.new do
#   importclient = ImportStatus.new("http://localhost:8081/solr", "monitortest", "myVre", nil, true)
#   importclient.start_import() #yields
# end
# puts "STARTING FIRST CLAIM"
# threadA.resume()
# puts "PAUSED"
# puts "STARTING SECOND CLAIM"
# importclient = ImportStatus.new("http://localhost:8081/solr", "monitortest", "myVre", nil, false)
# importclient.start_import()
# puts "SECOND CLAIM FINISHED"
# puts "CONTINUING FIRST CLAIM"
# threadA.resume()
