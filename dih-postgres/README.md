Let's fire up a Postgres DB with some data in it. Here's one I found on Docker hub:

```
$ docker run -d --name pg-ds-world aa8y/postgres-dataset:world

$ docker exec -it pg-ds-world bash

$ psql world
              List of relations
 Schema |      Name       | Type  |  Owner   
--------+-----------------+-------+----------
 public | city            | table | postgres
 public | country         | table | postgres
 public | countrylanguage | table | postgres
(3 rows)

world=# \d city
                     Table "public.city"
   Column    |     Type     | Collation | Nullable | Default 
-------------+--------------+-----------+----------+---------
 id          | integer      |           | not null | 
 name        | text         |           | not null | 
 countrycode | character(3) |           | not null | 
 district    | text         |           | not null | 
 population  | integer      |           | not null | 
Indexes:
    "city_pkey" PRIMARY KEY, btree (id)
Referenced by:
    TABLE "country" CONSTRAINT "country_capital_fkey" FOREIGN KEY (capital) REFERENCES city(id)

world=# select name from city limit 2;                                                                                                                                                                         name   
----------
 Kabul
 Qandahar
(2 rows)
```

let's see what its IP address is:

```
$ docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' pg-ds-world  
172.17.0.2
```

and double-check we can get there from another container:

```
docker run -it --rm --name pg-ds-world-client aa8y/postgres-dataset:world bash
bash-4.4$ psql -h 172.17.0.2 -U postgres world
Password for user postgres: 
psql (11.1)
Type "help" for help.

world=# \d
              List of relations
 Schema |      Name       | Type  |  Owner   
--------+-----------------+-------+----------
 public | city            | table | postgres
 public | country         | table | postgres
 public | countrylanguage | table | postgres
(3 rows)
```

OK, that's the DB running.


To talk to it from Solr we'll need a JDBC driver.
```
curl -O https://jdbc.postgresql.org/download/postgresql-42.2.6.jar
```
We'll use a Solr DIH [data-config.xml](data-config.xml):

```
<dataConfig>
  <dataSource type="JdbcDataSource" 
              driver="org.postgresql.Driver"
              url="${dataimporter.datasource.url}"
              user="${dataimporter.datasource.user}"
              password="${dataimporter.datasource.password}"/>
  <document>
    <entity name="id" 
            query="select id,name from city">
     <field column="id" name="id"/>
     <field column="name" name="name_str"/>
    </entity>
  </document>
</dataConfig>
```

Grab the solrconfig from the container:

```
docker create --name tmp1 solr:latest
docker cp tmp1:/opt/solr/server/solr/configsets/_default/conf/solrconfig.xml solrconfig.xml
docker rm tmp1
```

Modify the [solrconfig.xml](solrconfig.xml) to load the dataimporthandler, and add a requesthandler configuration for it:

```
ed solrconfig.xml <<'EOM'
$
?requestHandler>
a
<requestHandler name="/dataimport" class="org.apache.solr.handler.dataimport.DataImportHandler">
<lst name="defaults">
  <str name="config">data-config.xml</str>
</lst>
</requestHandler>
.

1
/regex="solr-velocity-
a
  <lib dir="${solr.install.dir:../../../..}/dist/" regex="solr-dataimporthandler-\d.*\.jar" />
  <lib dir="${solr.install.dir:../../../..}/contrib/dataimporthandler/lib" regex=".*\.jar" />
.
w
q
EOM
```

so that we end up with:
```
--- solrconfig.xml.orig	2019-06-22 12:34:11.000000000 +0100
+++ solrconfig.xml	2019-06-22 13:57:05.000000000 +0100
@@ -83,6 +83,8 @@
 
   <lib dir="${solr.install.dir:../../../..}/contrib/velocity/lib" regex=".*\.jar" />
   <lib dir="${solr.install.dir:../../../..}/dist/" regex="solr-velocity-\d.*\.jar" />
+  <lib dir="${solr.install.dir:../../../..}/dist/" regex="solr-dataimporthandler-\d.*\.jar" />
+  <lib dir="${solr.install.dir:../../../..}/contrib/dataimporthandler/lib" regex=".*\.jar" />
   <lib dir="${solr.install.dir:../../../..}/dist/" regex="solr-ltr-\d.*\.jar" />
 
   <!-- an exact 'path' can be used instead of a 'dir' to specify a
@@ -1003,6 +1005,14 @@
       <str>elevator</str>
     </arr>
   </requestHandler>
+<requestHandler name="/dataimport" class="org.apache.solr.handler.dataimport.DataImportHandler">
+<lst name="defaults">
+  <str name="config">data-config.xml</str>
+</lst>
+</requestHandler>
 
   <!-- Highlighting Component

```

To run:

```
docker run -it -p 8879:8983 \
  -v $PWD/solrconfig.xml:/opt/solr/server/solr/configsets/_default/conf/solrconfig.xml \
  -v $PWD/data-config.xml:/opt/solr/server/solr/configsets/_default/conf/data-config.xml \
  -v $PWD/postgresql-42.2.6.jar:/opt/solr/contrib/dataimporthandler/lib/postgresql-42.2.6.jar \
  -e SOLR_OPTS="-Ddataimporter.datasource.url=jdbc:postgresql://172.17.0.2/world -Ddataimporter.datasource.user=postgres -Ddataimporter.datasource.password=postgres" \
  solr:8 \
  solr-precreate core1
```

That's the core created.

Now go to 
http://localhost:8879/solr/#/core1/dataimport and hit Execute to do a full import.
Check the Solr log; there should be no errors.
Then go to http://localhost:8879/solr/#/core1/query and do a query -- you should see docs.
If you add `id,name_str` to the `fl` you should see the city names too.

