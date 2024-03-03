#!/bin/bash

if ! helm repo list | grep promethues-community; then
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
fi

helm upgrade \
    --install \
    prometheus-community/prometheus-kubernetes-stack \
    prometheus
