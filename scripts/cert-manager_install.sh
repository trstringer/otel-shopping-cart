#!/bin/bash

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml
while kubectl get po -n cert-manager --no-headers | grep -v Running; do
    echo "Waiting for cert-manager to come up..."
    sleep 5
done
sleep 10
echo "cert-manager is up"
