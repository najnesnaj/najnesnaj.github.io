---
title: 'Elastic'
weight: 440
draft: false
---

# configure elasticview

## elasticsearch password

connect with term to container:
bin/elasticsearch-reset-password -u elastic
bin/elasticsearch-reset-password -u elastic -i (this allows for setting it yourself)

## testing elasticview connection

curl -X GET -k -u elastic:ebktuBhBHtE7N+JeBbIV “https://192.168.0.121:9200/_cluster/health/?pretty”

{
: “cluster_name” : “docker-cluster”,
  “status” : “green”,
  “timed_out” : false,
  “number_of_nodes” : 1,
  “number_of_data_nodes” : 1,
  “active_primary_shards” : 1,
  “active_shards” : 1,
  “relocating_shards” : 0,
  “initializing_shards” : 0,
  “unassigned_shards” : 0,
  “delayed_unassigned_shards” : 0,
  “number_of_pending_tasks” : 0,
  “number_of_in_flight_fetch” : 0,
  “task_max_waiting_in_queue_millis” : 0,
  “active_shards_percent_as_number” : 100.0

}

## getting website certificate

connect to [http://192.168.0.121](http://192.168.0.121)

firefox/settings/privicy&security/certificates to add exception
