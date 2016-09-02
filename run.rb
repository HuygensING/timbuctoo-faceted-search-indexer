require "./lib/solr/timbuctoo_io"


timbuctoo_io = TimbuctooIO.new('http://localhost:8089', {:dump_files => true, :dump_dir => '/home/rar011/tmp'})


def process_record record
  puts "processing #{record['_id']}"
end


timbuctoo_io.scrape_collection("wwpersons", method(:process_record)) # fancy ruby shorthand
#timbuctoo_io.scrape_collection("wwpersons", -> (record) {process_record(record)}) # short lambda syntax
#timbuctoo_io.scrape_collection("wwpersons", lambda {|record| process_record(record)}) # lambda syntax