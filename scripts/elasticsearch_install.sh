#!/bin/bash

kubectl create -f https://download.elastic.co/downloads/eck/2.11.1/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.11.1/operator.yaml

cat <<EOF | kubectl apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: elasticsearch
  namespace: observability
spec:
  version: 8.12.2
  nodeSets:
  - name: default
    count: 1
    config:
      node.store.allow_mmap: false
EOF

cat <<EOF | kubectl apply -f -
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: kibana
  namespace: observability
spec:
  version: 8.12.2
  count: 1
  elasticsearchRef:
    name: elasticsearch
EOF
