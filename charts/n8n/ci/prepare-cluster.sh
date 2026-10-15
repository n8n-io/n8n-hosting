#!/usr/bin/env bash
# Creates the Secrets the overlays in install/ name and starts the Postgres and
# Redis fixtures, so every kind leg starts from the same cluster. The licence
# Secret is created only when ACTIVATION_KEY and TENANT_ID are set, which they
# are not on pull requests from forks.
set -euo pipefail

kubectl create secret generic n8n-db-secret \
  --from-literal=password=n8n-test-password
kubectl create secret generic n8n-core-secrets \
  --from-literal=N8N_ENCRYPTION_KEY=test-encryption-key-must-be-long-enough \
  --from-literal=N8N_HOST=localhost \
  --from-literal=N8N_PORT=5678 \
  --from-literal=N8N_PROTOCOL=http
kubectl create secret generic n8n-runner-token \
  --from-literal=auth-token="$(openssl rand -base64 32)"
# The fixture Redis has no password, and Redis accepts one anyway.
kubectl create secret generic n8n-redis-secret \
  --from-literal=password=unused
# The S3 mock accepts any credentials.
kubectl create secret generic n8n-s3-secret \
  --from-literal=secret-access-key=unused

# Written to files rather than passed as arguments, so the key never appears
# in a process list.
if [[ -n "${ACTIVATION_KEY:-}" && -n "${TENANT_ID:-}" ]]; then
  dir=$(mktemp -d)
  trap 'rm -rf "$dir"' EXIT
  printf '%s' "$ACTIVATION_KEY" > "$dir/license-key"
  printf '%s' "$TENANT_ID" > "$dir/tenant-id"
  kubectl create secret generic n8n-license \
    --from-file=license-key="$dir/license-key" \
    --from-file=tenant-id="$dir/tenant-id"
else
  echo "No licence secrets on this run."
fi

kubectl apply -f "$(dirname "$0")/fixtures/"
kubectl rollout status deployment/postgres --timeout=120s
kubectl rollout status deployment/redis --timeout=120s
