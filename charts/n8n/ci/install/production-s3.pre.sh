#!/usr/bin/env bash
# Starts the S3 mock that stands in for the bucket in examples/production-s3.yaml.
set -euo pipefail

kubectl apply -f charts/n8n/ci/fixtures/s3/
kubectl rollout status deployment/s3mock --timeout=180s
