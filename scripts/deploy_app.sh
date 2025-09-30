#!/bin/bash

set -e

kubectl apply -f /home/ubuntu/k8s/dr-deployment.yaml
kubectl apply -f /home/ubuntu/k8s/hpa.yaml
kubectl apply -f /home/ubuntu/k8s/ingress.yaml
kubectl apply -f /home/ubuntu/k8s/cluster_autoscaler.yaml
