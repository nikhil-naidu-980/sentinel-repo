#!/bin/bash
set -e

REGION=${AWS_REGION:-us-west-2}
BACKEND_CLUSTER=${BACKEND_CLUSTER:-eks-backend}

echo "Installing Calico on Backend cluster ($BACKEND_CLUSTER)"
aws eks update-kubeconfig --name "$BACKEND_CLUSTER" --region "$REGION" >/dev/null
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

echo "Waiting for Calico DaemonSet to be ready"
kubectl rollout status daemonset/calico-node -n kube-system --timeout=300s

echo "Applying NetworkPolicy to Backend cluster"
kubectl apply -f kubernetes/backend/network-policy.yaml

echo "Calico installed successfully on backend cluster!"



