#!/bin/bash

if ! helm repo list | grep promethues-community; then
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
helm upgrade \
    -n observability \
    --install \
    -f "${SCRIPT_DIR}/kube-prometheus-stack_values.yaml" \
    prometheus \
    prometheus-community/kube-prometheus-stack
