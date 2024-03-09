#!/bin/bash

echo "Running e2e tests"

if ! make kind-create; then
    echo "Failed to make kind"
    exit 1
fi
make stop-local

if ! make run-local; then
    echo "Failed deploy"
    exit 1
fi

echo "Waiting for pods to all come up"
until ! kubectl get po -A | grep ContainerCreating; do
    echo "Pods still creating"
    sleep 5
done

sleep 60
MAX_ITERATIONS=20
CURRENT_ITERATION=0
while [[ $CURRENT_ITERATION -lt $MAX_ITERATIONS ]]; do
    if ! kubectl get po -A --no-headers | grep -v Running | grep -v Completed; then
        echo "Cluster successfully running"
        make stop-local
        exit
    fi
    echo "Found pods in a state other than Running or Completed"
    CURRENT_ITERATION=$((CURRENT_ITERATION + 1))
    sleep 10
done

echo "Cluster not successfully running"
make stop-local
exit 1
