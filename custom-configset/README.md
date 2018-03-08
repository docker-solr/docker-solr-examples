Using a custom configset
========================

This example shows how to use a custom configset.

This may not be advisable: editing the schema XML is error-prone, and storing
modified config files makes it harder to keep up-to-date with changes in newer
versions. See the `schema-api` example for a different approach.


Modifying the configset
-----------------------

First we copy the `_default` configset in Solr:

```
docker create --rm --name copier solr
docker cp copier:/opt/solr/server/solr/configsets/_default myconfig
docker rm copier
```

To add a field, modify `./myconfig/conf/managed-schema`.
For example, to add a field, locate the section with `<field name=` entries and
append:

```
    <field name="myfield" type="text_general" multiValued="true" indexed="true" stored="false"/>
```

You can do that with an editor, or with these commands:

```
cp myconfig/conf/managed-schema myconfig/conf/managed-schema.orig
sed -e '/<field name="id"/a\'$'\n''\    <field name="myfield" type="text_general" multiValued="true" indexed="true" stored="false"\/>' myconfig/conf/managed-schema > myconfig/conf/managed-schema.modified
diff -du myconfig/conf/managed-schema myconfig/conf/managed-schema.modified
mv myconfig/conf/managed-schema.modified myconfig/conf/managed-schema
```

See the [Overview of Documents, Fields, and Schema Design](https://cwiki.apache.org/confluence/display/solr/Overview+of+Documents%2C+Fields%2C+and+Schema+Design) for a full explanation of the Solr schema.


Using the configset
-------------------

To use this with docker-solr, you need to mount this configset into the
container (we'll mount it read-only), and then you can use it when creating a core:

```
docker run -d --name solr-core5 -p 8983:8983 \
  -v $PWD/myconfig:/opt/solr/server/solr/configsets/myconfig:ro \
  solr solr-precreate core5 /opt/solr/server/solr/configsets/myconfig
```


Custom Docker Image
-------------------

If you don't want to use the host-mounted directory, you can always create a
custom docker image that contains your custom configuration (here called `myconfig`):

```
mkdir custom-image
cp -r myconfig custom-image/
cat > custom-image/Dockerfile <<'EOM'
FROM solr
ADD myconfig /opt/solr/server/solr/configsets/myconfig
EOM
(cd custom-image; docker build -t my-image .)
```

Then run:

```
docker run -p 8983:8983 my-image \
  solr-precreate core6 /opt/solr/server/solr/configsets/myconfig
```

Note
----
One note of caution: we've copied the configset from a specific version of Solr.
It's possible that a future version will have changes to those config files; it will
be up to you to re-generate your config.
