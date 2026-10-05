#!/usr/bin/env bash
# Checks each n8n pod selects, and landed in, the pool
# examples/node-placement.yaml asks for. A pod that lost its nodeSelector can
# still land in the right pool by chance, so the selector is checked as well
# as the node.
set -euo pipefail

check() {
  local component=$1 pool=$2
  local pods found=0
  pods=$(kubectl get pods -l "app.kubernetes.io/component=${component}" \
    -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.nodeName}{" "}{.spec.nodeSelector.pool}{"\n"}{end}')
  while read -r pod node selector; do
    [[ -z "$pod" ]] && continue
    found=1
    if [[ "$selector" != "$pool" ]]; then
      echo "::error::${pod} selects pool '${selector}', expected '${pool}'."
      exit 1
    fi
    actual=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.pool}')
    if [[ "$actual" != "$pool" ]]; then
      echo "::error::${pod} is on ${node} (pool '${actual}'), expected pool '${pool}'."
      exit 1
    fi
  done <<< "$pods"
  if [[ "$found" == 0 ]]; then
    echo "::error::No ${component} pods found."
    exit 1
  fi
  echo "${component} pods are in pool ${pool}."
}

check main n8n-frontend
check webhook-processor n8n-frontend
check worker n8n-workers
