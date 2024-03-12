#!/bin/bash

if ! helm repo list | grep grafana; then
    helm repo add grafana https://grafana.github.io/helm-charts
fi
helm repo update

helm upgrade \
    -n observability \
    --install \
    tempo \
    grafana/tempo
