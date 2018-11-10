#!/bin/bash
#
# This script starts Solr on localhost, creates a core with "solr create",
# configures it with the Schema API, stops Solr, and then starts Solr as normal.
# Any arguments are passed to the "solr create".
# To simply create a core:
#      docker run -p 8983:8983 -d -v $PWD/myscript.sh:/myscript.sh:ro \
#          solr /myscript.sh -c mycore

set -e
echo "Executing $0 $@"

# allow easier debugging with `docker run -e VERBOSE=yes`
if [[ "$VERBOSE" = "yes" ]]; then
    set -x
fi

# run the optional initdb
. /opt/docker-solr/scripts/run-initdb

# keep a sentinel file so we don't try to create the core a second time
# for example when we restart a container.
sentinel=/opt/docker-solr/core_created
if [ -f $sentinel ]; then
    echo "skipping core creation"
else
    # start a Solr so we can use the Schema API, but only on localhost,
    # so that clients don't see Solr until we have configured it.
    start-local-solr

    echo "Creating core with: ${@:1}"
    /opt/solr/bin/solr create "${@:1}"

    # See https://github.com/docker-solr/docker-solr/issues/27
    echo "Checking core"
    if ! wget -O - 'http://localhost:8983/solr/admin/cores?action=STATUS' | grep -q instanceDir; then
      echo "Could not find any cores"
      exit 1
    fi

    echo "Created core with: ${@:1}"

    # get the core name.
    core_name=$(wget -q -O - 'http://localhost:8983/solr/admin/cores?wt=xml'|grep -E -o '<str name="name">([^>]+)</str>'|sed -r -e 's/<[^>]*>//' -e 's/<[^>]*>//')
    if [[ -z $core_name ]]; then
        echo "could not determine core name"
        exit 1
    fi

    # Now configure with the Schema API
    # Modify this with your desired schema configuration
    curl -X POST -H 'Content-type:application/json' --data-binary '{
  "add-field":{
    "name":"sell-by",
    "type":"pdate",
    "stored":true
    }
}' http://localhost:8983/solr/$core_name/schema

    echo "finished configuring with the Schema API"

    stop-local-solr

    # move the core to "mycores" so users can mount a directory there
    mv "/opt/solr/server/solr/$core_name" /opt/solr/server/solr/mycores/

    touch $sentinel
fi

# Now run Solr in the foreground, listening to all interfaces
exec solr -f
