#!/usr/bin/env bash
# Checks each n8n pod landed in the pool examples/node-placement.yaml asks for.
set -euo pipefail

check() {
  local component=$1 pool=$2
  local nodes
  nodes=$(kubectl get pods -l "app.kubernetes.io/component=${component}" \
    -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}')
  if [[ -z "$nodes" ]]; then
    echo "::error::No ${component} pods found."
    exit 1
  fi
  while read -r node; do
    actual=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.pool}')
    if [[ "$actual" != "$pool" ]]; then
      echo "::error::A ${component} pod is on ${node} (pool '${actual}'), expected pool '${pool}'."
      exit 1
    fi
  done <<< "$nodes"
  echo "${component} pods are in pool ${pool}."
}

check main n8n-frontend
check webhook-processor n8n-frontend
check worker n8n-workers
