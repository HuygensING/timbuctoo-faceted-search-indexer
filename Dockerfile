FROM ruby:2.2

EXPOSE 80

ENV TIMBUCTOO_SCRAPE_URL http://timbuctoo
ENV SOLR_URL http://solr/solr

RUN mkdir -p /app
COPY webserver/Gemfile /app/webserver/Gemfile
RUN cd /app/webserver && bundle install
COPY dcar /app/dcar
COPY womenwriters /app/womenwriters
COPY federated-indexer /app/federated-indexer
COPY generic-indexer /app/generic-indexer
COPY lib /app/lib
COPY webserver /app/webserver

CMD ["ruby", "/app/webserver/web.rb", "-p", "80", "-o", "0.0.0.0"]

