#!/bin/bash

JAEGER_OPERATOR_URI="https://github.com/jaegertracing/jaeger-operator/releases/download/v1.49.0/jaeger-operator.yaml"
until kubectl create -f "$JAEGER_OPERATOR_URI" -n observability; do
    kubectl delete -f "$JAEGER_OPERATOR_URI" -n observability
    echo "Waiting for jaeger operator to come up..."
    sleep 5
done

until kubectl create -n observability -f ./kubernetes/jaeger.yaml; do
    echo "Waiting for jaeger to install successfully..."
    sleep 5
done
