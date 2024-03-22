#!/bin/bash

if ! helm repo list | grep grafana; then
    helm repo add grafana https://grafana.github.io/helm-charts
fi
helm repo update

helm upgrade \
    -n observability \
    --install \
    --set loki.commonConfig.replication_factor=1 \
    --set loki.storage.type=filesystem \
    --set singleBinary.replicas=1 \
    loki \
    grafana/loki
