# Solr index script

This folder contains scripts that scrape timbuctoo and send the data to solr.

## Context
We want to be able expose Timbuctoo collections through solr/lucene in a flexible way,
enabling indexes on both the direct properties of records in a collection, as well as
key properties of directly related objects; for instance a keyword value from a keyword 
collection, which was linked to a document from a document collection (like genre).


## Usage
Creating an index for a Timbuctoo collection is a 3-step process:

1. Scrape Timbuctoo data
2. Convert to solr docs
3. Send solr docs to solr server

### Libraries
For that purpose there are three classes in the dir ```lib/timbuctoo_solr```.

1. TimbuctooIO ```lib/timbuctoo_solr/timbuctoo_io.rb```
2. DefaultMapper ```lib/timbuctoo_solr/default_mapper.rb```
3. SolrIO ```lib/timbuctoo_solr/solr_io.rb```

The next sections will explain the 3-step process in more detail, using examples which 
can be found in the ```samples``` dir.

### Scraping
A scrape of a Timbuctoo collection is done in batches using the method 
```scrape_collection``` in TimbuctooIO.

#### Basic scrape
This script above scrapes the collection 'dcararchives' from the Timbuctoo test repository:
```ruby
# samples/basic-scrape.rb
require '../lib/timbuctoo_solr/timbuctoo_io'

timbuctoo_io = TimbuctooIO.new('http://test.repository.huygens.knaw.nl')
timbuctoo_io.scrape_collection('dcararchives')    
```
Its default behaviour is to fetch the records in batches of 100, without relations, dumping
each record individually to standard output.

Sample of the output:
```
{"beginDate"=>"1700", "countries"=>["NL"], "endDate"=>"1800", "extent"=>"1 folder", "itemNo"=>"9169", "madeBy"=>"MS", "notes"=>"18th century.", "origFilename"=>"/data/data_Atlantische_wereld/Archieven/Archief_Nederlandse_Jezuieten_Nijmegen/Handschriftenverzameling/AD9_9169", "refCode"=>"AD.9", "refCodeArchive"=>"Archief Nederlandse Jezuieten", "reminders"=>"Gegevens ontvangen van Hans de Valk, 19-4-2007", "titleEng"=>"Documents relating to the RC mission on Curaçao in the 18th century", "titleNld"=>"Stukken betreffende de missie op Curaçao in de 18e eeuw", "@displayName"=>"Stukken betreffende de missie op Curaçao in de 18e eeuw", "^rev"=>1, "^modified"=>{"timeStamp"=>1411642687699, "userId"=>"importer", "vreId"=>"dcar"}, "^created"=>{"timeStamp"=>1411642687699, "userId"=>"importer", "vreId"=>"dcar"}, "@variationRefs"=>[{"id"=>"778bb9f8-a4fa-4a55-aed3-997da73112a0", "type"=>"archive"}, {"id"=>"778bb9f8-a4fa-4a55-aed3-997da73112a0", "type"=>"dcararchive"}], "^deleted"=>false, "_id"=>"778bb9f8-a4fa-4a55-aed3-997da73112a0"}
{"beginDate"=>"1670", "countries"=>["NL"], "endDate"=>"1870", "extent"=>"1 folder", "itemNo"=>"9170", "madeBy"=>"MS", "notes"=>"Undated.", "origFilename"=>"/data/data_Atlantische_wereld/Archieven/Archief_Nederlandse_Jezuieten_Nijmegen/Handschriftenverzameling/AD10_9170", "refCode"=>"AD.10", "refCodeArchive"=>"Archief Nederlandse Jezuieten", "reminders"=>"Gegevens ontvangen van Hans de Valk, 19-4-2007", "titleEng"=>"(Handwritten) notes concerning the Jesuit mission and missionaries in Suriname and Curaçao during the Republic and in the 19th century", "titleNld"=>"(Handgeschreven) aantekeningen betreffende de missie en missionarissen SJ in Suriname en Curaçao zowel onder de Republiek als in de 19e eeuw", "@displayName"=>"(Handgeschreven) aantekeningen betreffende de missie en missionarissen SJ in Suriname en Curaçao zowel onder de Republiek als in de 19e eeuw", "^rev"=>1, "^modified"=>{"timeStamp"=>1411642687699, "userId"=>"importer", "vreId"=>"dcar"}, "^created"=>{"timeStamp"=>1411642687699, "userId"=>"importer", "vreId"=>"dcar"}, "@variationRefs"=>[{"id"=>"bead3064-ada9-4ee5-aad0-e5a926026574", "type"=>"archive"}, {"id"=>"bead3064-ada9-4ee5-aad0-e5a926026574", "type"=>"dcararchive"}], "^deleted"=>false, "_id"=>"bead3064-ada9-4ee5-aad0-e5a926026574"}
```


#### Configuring the scrape
The code block below documents some options exposed by TimbuctooIO to alter scraping behaviour.
```ruby
# samples/basic-scrape.rb

# Will dump scraped files (json) to specified :dump_dir
timbuctoo_io = TimbuctooIO.new('http://test.repository.huygens.knaw.nl', {
    :dump_files => true,
    :dump_dir => './'
})
timbuctoo_io.scrape_collection('dcararchives', {
    :with_relations => true, # also scrape direct relations
    :batch_size => 1000, # scrape in batches of 1000
})
```

Dumping files has the advantage of not having to re-scrape the collection during development. 
The filenames of the dump files have a signature reflecting the parameters of the scrape.
For instance, the above example outputs files with this format: ```dcararchives_rows_1000_start_1000_with_relations.json```

#### Re-scraping from locally dumped files
To scrape from the locally dumped files in stead of Timbuctoo, add the ```:from_file``` flag to the
```scrape_collection``` method. In this case the value of ```:dump_dir``` in the constructor must
match the location of the dumped files. If the (some of the) files are not present, TimbuctooIO
will fall back on scraping the Timbuctoo server. 
```ruby
# samples/basic-scrape.rb

timbuctoo_io.scrape_collection('dcararchives', {
    :with_relations => true, # also scrape direct relations
    :batch_size => 1000, # scrape in batches of 1000
    :from_file => true # scrape from local file dump in stead of Timbuctoo, if files are present
})
```

### Converting




## Open issues

### 1. No control over text indexes
Our current solr index is the default data driven index. 
This one does not handle accented words very well. 
We also have no control over how capitalization is handled.
We're pretty sure that our users need us to handle these cases in a way that differs on a project by project basis.

#### Development steps
- Run a local solr 6 instance (docker or directly under windows, you'll need to be able to access the files)
- create the index `wwpersons_accent_research` on your local solr
- Fill this index with the fulltext records (i.e. `*_t`) uit wwpersons
- Configure it so that 
 1. a search for `Bronte` and a search fot `Brontë` both return one instance for each of the three Brontë sisters
 2. a search for `de*` return both "Descartes" and "Eugénie Avril de Sainte Croix". A Search for `De*` returns only Descartes
 3. Find out how we could make the index fully case-sensitive
- How can we make this approach work for all `*_t` fields?
- How can we make this approach work for only a specific field?
