#!/bin/bash

echo "Running e2e tests"

make deploy

echo "Waiting for pods to all come up"
until ! kubectl get po -A | grep ContainerCreating; do
    echo "Pods still creating"
    sleep 5
done

sleep 15

if kubectl get po -A --no-headers | grep -v Running | grep -v Completed; then
    echo "Found pods in a state other than Running or Completed"
    exit 1
fi

echo "Cluster successfully running"
make clean
