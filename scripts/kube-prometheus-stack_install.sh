#!/bin/bash

if ! helm repo list | grep promethues-community; then
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
fi

helm upgrade \
    --install \
    --set "grafana.grafana\.ini.auth\.anonymous.enabled=true" \
    --set "grafana.grafana\.ini.auth\.anonymous.org_role=Editor" \
    --set "grafana.grafana\.ini.auth.disable_login_form=true" \
    --set "grafana.grafana\.ini.auth.disable_signout_menu=true" \
    --set "grafana.grafana\.ini.users.disable_signout_menu=true" \
    prometheus \
    prometheus-community/kube-prometheus-stack
