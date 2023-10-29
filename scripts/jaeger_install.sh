#!/bin/bash

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml

kubectl create namespace observability
JAEGER_OPERATOR_URI="https://github.com/jaegertracing/jaeger-operator/releases/download/v1.49.0/jaeger-operator.yaml"
until kubectl create -f "$JAEGER_OPERATOR_URI" -n observability; do
    kubectl delete -f "$JAEGER_OPERATOR_URI" -n observability
    echo Waiting for cert-manager to be ready for jaeger
    sleep 10
done

until kubectl create -f ./kubernetes/jaeger.yaml; do
    echo Waiting for jaeger to be installed
    sleep 10
done
