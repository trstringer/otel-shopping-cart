#!/bin/bash

echo "Running e2e tests"

if ! make kind-create; then
    echo "Failed to make kind"
    exit 1
fi
make clean

if ! make deploy; then
    echo "Failed deploy"
    exit 1
fi

echo "Waiting for pods to all come up"
until ! kubectl get po -A | grep ContainerCreating; do
    echo "Pods still creating"
    sleep 5
done

sleep 60

if kubectl get po -A --no-headers | grep -v Running | grep -v Completed; then
    echo "Found pods in a state other than Running or Completed"
    kubectl get po -A --no-headers | grep -v Running | grep -v Completed |
        awk '{print $2}' | xargs -rn 1 kubectl logs
    exit 1
fi

echo "Cluster successfully running"
make clean
