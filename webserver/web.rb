require 'sinatra'
require 'sinatra/base'
require 'sinatra/cross_origin'
# require 'httplog'

require_relative '../generic-indexer/generic_indexer'
require_relative '../federated-indexer/federated_indexer'
require_relative '../dcar/dutch_caribbean_indexer'
require_relative '../womenwriters/women_writers_indexer'

options "/trigger" do
  cross_origin
  response.headers["Allow"] = "POST,OPTIONS"
  response.headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"
  status 204
  ""
end
post '/trigger' do
  cross_origin
  begin
    payload = JSON.parse(request.body.read)
    if payload.key?("datasetName")
      if payload["datasetName"] == "DutchCaribbean"
        DutchCaribbeanIndexer.new(
          :timbuctoo_url => ENV['TIMBUCTOO_SCRAPE_URL'],
          :solr_url => ENV['SOLR_URL']
        ).run
        status 200
        return
      elsif payload["datasetName"] == "WomenWriters"
        DutchCaribbeanIndexer.new(
          :timbuctoo_url => ENV['TIMBUCTOO_SCRAPE_URL'],
          :solr_url => ENV['SOLR_URL']
        ).run
        status 200
        return
      else
        GenericIndexer.new(
            :vre_id => payload["datasetName"],
            :timbuctoo_url => ENV['TIMBUCTOO_SCRAPE_URL'],
            :solr_url => ENV['SOLR_URL']
        ).run
        status 200
        return
      end
    end
    status 400
  rescue Exception => e
    status 500
    raise e
  end
end
options "/status/:datasetName" do
  cross_origin
  response.headers["Allow"] = "HEAD,GET,OPTIONS"
  response.headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"
  status 204
  ""
end
get '/status/:datasetName' do
  cross_origin
  begin
    status 200
    headers \
      "Content-Type" => "application/json"
    ImportStatus.new(ENV['SOLR_URL'], "monitor", params['datasetName']).get_progress().to_json()
  rescue Exception => e
    status 500
    raise e
  end
end
options "/trigger-multi-collection-search" do
  cross_origin
  response.headers["Allow"] = "POST,OPTIONS"
  response.headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"
  status 204
  ""
end
post '/trigger-multi-collection-search' do
  begin
    FederatedIndexer.new(
        :timbuctoo_url => ENV['TIMBUCTOO_SCRAPE_URL'],
        :solr_url => ENV['SOLR_URL']
    ).run
    status 200
  rescue Exception => e
    status 500
    raise e
  end
end
