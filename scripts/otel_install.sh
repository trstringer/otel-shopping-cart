#!/bin/bash

# kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
if ! helm repo list | grep promethues-community; then
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo update
fi

helm upgrade \
    --install \
    otel-operator \
    open-telemetry/opentelemetry-operator

# nodes: [get,list,watch]
# services: [get,list,watch]
# namespaces: [get,list,watch]
# configmaps: [get]
# networking.k8s.io/ingresses: [get,list,watch]
# monitoring.coreos.com/servicemonitors: [*]
# monitoring.coreos.com/podmonitors: [*]
# pods: [get,list,watch]
# discovery.k8s.io/endpointslices: [get,list,watch]
# nonResourceURL: /metrics: [get]
# nodes/metrics: [get,list,watch]
# endpoints: [get,list,watch]

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otelcol
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: opentelemetry-targetallocator-cr-role
rules:
- apiGroups:
  - monitoring.coreos.com
  resources:
  - servicemonitors
  - podmonitors
  verbs:
  - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: otelcol-prom
subjects:
  - kind: ServiceAccount
    name: otelcol
    namespace: default
roleRef:
  kind: ClusterRole
  name: opentelemetry-targetallocator-cr-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: opentelemetry-targetallocator-role
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/metrics
  - services
  - endpoints
  - pods
  - namespaces
  - secrets
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - configmaps
  verbs: ["get"]
- apiGroups:
  - discovery.k8s.io
  resources:
  - endpointslices
  verbs: ["get", "list", "watch"]
- apiGroups:
  - networking.k8s.io
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: otelcol-discovery
subjects:
  - kind: ServiceAccount
    name: otelcol
    namespace: default
roleRef:
  kind: ClusterRole
  name: opentelemetry-targetallocator-role
  apiGroup: rbac.authorization.k8s.io
EOF

while [[ $(kubectl get po -l app.kubernetes.io/name=opentelemetry-operator -o jsonpath='{.items[0].status.phase}') != "Running" ]]; do
    echo "Waiting for the operator to come up"
    sleep 5
done
echo "Operator running"
sleep 10
