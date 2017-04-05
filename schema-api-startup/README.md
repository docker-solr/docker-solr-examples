Configuring your core at startup with the Schema API
====================================================

This example shows how you can use a script to create a core,
and configure it with the Schema API all at runtime.

Run:

```
docker run -p 8983:8983 -d \
    -v $PWD/myscript.sh:/myscript.sh:ro \
    solr /myscript.sh -c mycore
```

wait 10 seconds or so, then verify on http://localhost:8983/solr/#/mycore/schema
that the core has the `sell-by` field configured.

See the `./myscript.sh` to see how it works, and modify the
Schema API calls to your requirements.

See the [Schema API documentation](https://cwiki.apache.org/confluence/display/solr/Schema+API)
for other examples, the [Overview of Documents, Fields, and Schema Design](https://cwiki.apache.org/confluence/display/solr/Overview+of+Documents%2C+Fields%2C+and+Schema+Design) for a full explanation of the Solr schema.

The advantage of this approach is that it is very easy to use
once you have created the script, and doesn't require any local
setup or modifications other than the script. It's easy to use
from Docker compose. The disadvantage is that this takes longer
than a startup where the core is already prepared. See the
[schema-api](../schema-api/README.md) example.