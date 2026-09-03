#!/bin/sh
base_url="https://raw.githubusercontent.com/eoda-dev/infra-bootstrap/main/rlang/k8s"

kubectl apply -f "$base_url/storage.yml"
kubectl apply -f "$base_url/install-r-packages-job.yml"
kubectl wait --for=condition=complete job/install-r-packages --timeout=300s
kubectl apply -f "$base_url/r-base-pod.yml"
