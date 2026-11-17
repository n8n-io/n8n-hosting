#!/usr/bin/env bash
# Checks KEDA accepted the worker ScaledObject and created the HPA behind it.
set -euo pipefail

kubectl wait scaledobject/n8n-worker --for=condition=Ready --timeout=120s
kubectl get hpa keda-hpa-n8n-worker
