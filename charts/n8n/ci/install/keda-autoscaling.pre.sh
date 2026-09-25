#!/usr/bin/env bash
# Installs KEDA, which examples/keda-autoscaling.yaml expects the cluster to run.
set -euo pipefail

helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --version 2.21.0 \
  --namespace keda --create-namespace \
  --wait --timeout 300s
