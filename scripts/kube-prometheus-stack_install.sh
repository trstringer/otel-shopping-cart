#!/bin/bash

if ! helm repo list | grep promethues-community; then
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
fi

helm upgrade \
    -n observability \
    --install \
    --set "grafana.grafana\.ini.auth\.anonymous.enabled=true" \
    --set "grafana.grafana\.ini.auth\.anonymous.org_role=Editor" \
    --set "grafana.grafana\.ini.auth.disable_login_form=true" \
    --set "grafana.grafana\.ini.auth.disable_signout_menu=true" \
    --set "grafana.grafana\.ini.users.disable_signout_menu=true" \
    --set "prometheus.prometheusSpec.serviceMonitorSelector.matchLabels.release=otel" \
    --set "prometheus.prometheusSpec.podMonitorSelector.matchLabels.release=otel" \
    prometheus \
    prometheus-community/kube-prometheus-stack
