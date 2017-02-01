## Starting the web app
The indexer can also be started through the generic search webapp, when the correct environment variables are set.

```sh
$ export TIMBUCTOO_SCRAPE_URL=http://localhost:8080
$ export TIMBUCTOO_BROWSER_URL=http://localhost:8080
$ export SOLR_URL=http://localhost:8983/solr
$ export PORT=4567
$ foreman start
```

Then navigate to http://localhost:4567?vreId=TheIdOfYourVre

## Running the webapp with docker
There is also a Dockerfile wrapping the web-app in /src/main/scripts/index_scripts.


```sh
$ docker build -t huygensing/timbuctoo-generic-search .
$ docker run -p -e SOLR_URL='http://solr' -e TIMBUCTOO_SCRAPE_URL='http://timbuctoo' TIMBUCTOO_BROWSER_URL='http://localhost:8080' 80:80 huygensing/timbuctoo-generic-search
```


## Dependencies

The web app requires ruby 2.2 and also depends on the ruby gem 'bundler' and ruby development package

```sh
$ apt-get install ruby-dev # (may require root permissions)
$ gem install bundler # (may require root permissions)
```

## Installing the web app dependencies

```sh
$ bundle install # (may require root permissions)   
```

## Client app

A javascript app that can trigger this indexer and read from the solr server is developed at https://github.com/HuygensING/timbuctoo-gui/tree/master/timbuctoo-generic-search-client
