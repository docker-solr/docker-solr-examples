Preconfiguring with the Schema API
==================================

The idea behind the [Schema API](https://cwiki.apache.org/confluence/display/solr/Schema+API)
is that you can make schema modifications via an API rather than having to make modifications
to a static `schema.xml`. This allows an application to create a core and then configure
its schema automatically. Even for manual modifications it can be nice to use, as the Schema
API will do some validation, and make sure you do not corrupt the XML configuration.
Internally, Solr modifies the XML file on your behalf.

Sometimes though you may have an application that requires you to create and 
configure the core manually before starting the application. In automated deployments
like Docker that can be tricky. One way to achieve this is to create the desired
configuration ahead of time, then use the result in future containers.
Here is an example.

First, create a Solr container with a core: 

```
docker run --rm -d --name solr-initial -p 8983:8983 solr solr-precreate initial_core
```

Verify this started, on http://localhost:8983/solr/#/initial_core

Now you can use the Schema API to create fields:

```
curl -X POST -H 'Content-type:application/json' --data-binary '{
  "add-field":{
    "name":"sell-by",
    "type":"tdate",
    "stored":true
    }
}' http://localhost:8983/solr/initial_core/schema
```

See the [Schema API documentation](https://cwiki.apache.org/confluence/display/solr/Schema+API)
for other examples, the [Overview of Documents, Fields, and Schema Design](https://cwiki.apache.org/confluence/display/solr/Overview+of+Documents%2C+Fields%2C+and+Schema+Design) for a full explanation of the Solr schema.

Now we can copy the entire core directory from the container, and kill the container:

```
docker cp solr-initial:/opt/solr/server/solr/mycores/initial_core coredir
docker kill solr-initial
```

Remove the data directory from the core (a new one will be created by Solr when it starts):

```
rm -fr coredir/data
```

Verify the added field is contained in the schema configuration:

```
$ grep sell-by coredir/conf/managed-schema
  <field name="sell-by" type="tdate" stored="true"/>
```

Great; now we can use that configuration in future containers,
check these files into a source control system, or package it up
for distribution.

Of course you could also make further manual configuration changes to the
`managed-schema` file or any of the other files in the `coredir` directory.
In fact the use of the Schema API above is optional, and you could just copy
the unmodified default, then locally modify; that also has the advantage you
can see the comments in the file which the Schema API discards when it rewrites
the file.

There are various ways you can now make use of this configuration in your containers.

Pre-create Docker Volume
------------------------

If you want to run a single Solr instance, and keep your config and data on a
named Docker volume, then you can do as follows: create the volume, copy the
core configuration to the volume:

```
docker volume create core2
# to copy to a volume we need to create a container (which need not be running).
# to chown the volume for Solr, we need to run a container as root.
# here we combine the two:
docker create --rm --name copier --user root -v core2:/d solr chown -R 8983:8983 /d
docker cp coredir/conf copier:/d/
docker cp coredir/core.properties copier:/d/
docker start copier
# the copier container will immediately exit
```

So at this point you have a pre-configured core in the volume, ready to go.
Just mount it in the Solr container, under the name you want to give the core (here `core2`):

```
docker run -d --name solr-core2 -p 8983:8983 -v core2:/opt/solr/server/solr/core2 solr
```

or you can use it with the `./docker-compose.yml`:

```
docker-compose up
```

Then you can use the [Schema Editor](http://localhost:8983/solr/#/core2/schema) to
verify it has your configuration.


Using as a configset
--------------------

If you want to re-use this configuration for multiple Solr instances, then you
can use this configuration as a tempconfigsetlate; we just need to make sure there is no
`core.properties` file, otherwise Solr will try to create a core there.
We could do it in a similar way to the volume above, or we could use a host-mounted
directory, mounted read-only:

```
rm coredir/core.properties

docker run -d --name solr-core3 -p 8983:8983 \
  -v $PWD/coredir:/opt/solr/server/solr/configsets/mine:ro \
  solr solr-precreate core3 /opt/solr/server/solr/configsets/mine
```


Custom Docker Image
-------------------

If you don't want to mess around with volumes, you can always create a custom docker image
that contains your custom configuration (here called `mine`):

```
mkdir custom-image
cp -r coredir custom-image/
cat > custom-image/Dockerfile <<'EOM'
FROM solr
ADD coredir /opt/solr/server/solr/configsets/mine
EOM
(cd custom-image; docker build -t my-image .)
```

Then run:

```
docker run -p 8983:8983 my-image \
  solr-precreate core4 /opt/solr/server/solr/configsets/mine
```

Note
----
One note of caution: we've copied the managed-schema from a specific version of Solr.
It's possible that a future version will have changes to those config files; it will
be up to you to re-generate your config.
