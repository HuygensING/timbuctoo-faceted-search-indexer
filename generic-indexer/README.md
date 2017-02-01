# Generic indexer

These scripts are meant to create a _generic_ for a Timbuctoo collection index 
based on its archetype.

It is meant to be run on new imported Timbuctoo sets, which will provide a dynamically created vreId.


## Running from command line
The indexer can be started via the run.rb script (see source for expected parameters):

```ruby
   opts.on('-d', '--dump-dir DIR', 'Save dump of scraped Timbuctoo into a dir') 
   opts.on('-f', '--from-file', 'Scrape timbuctoo from local file cache') 
   opts.on('-t', '--timbuctoo-url TIM_URL', 'Base url for Timbuctoo') 
   opts.on('-s', '--solr-url SOLR_URL', 'Base url for Timbuctoo') 
   opts.on('-a', '--solr-auth AUTH', 'Value for Authentication header of solr server') 
   opts.on('-V', '--vre-id VRE', 'The VRE ID to scrape')
```

## Dependencies

This script requires ruby 2.2 and upwards, but no further gems.

## Javascript sources for client app are from this project:

https://github.com/HuygensING/timbuctoo-generic-search-client/tree/master
