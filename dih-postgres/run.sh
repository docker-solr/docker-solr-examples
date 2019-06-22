#!/bin/bash
docker run -it -p 8879:8983 \
  -v $PWD/solrconfig.xml:/opt/solr/server/solr/configsets/_default/conf/solrconfig.xml \
  -v $PWD/data-config.xml:/opt/solr/server/solr/configsets/_default/conf/data-config.xml \
  -v $PWD/postgresql-42.2.6.jar:/opt/solr/contrib/dataimporthandler/lib/postgresql-42.2.6.jar \
  -e SOLR_OPTS="-Ddataimporter.datasource.url=jdbc:postgresql://172.17.0.2/world -Ddataimporter.datasource.user=postgres -Ddataimporter.datasource.password=postgres" \
  solr:8 \
  solr-precreate core1
