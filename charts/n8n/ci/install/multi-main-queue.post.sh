#!/usr/bin/env bash
# Checks both mains are up in multi-main mode and the licence activated.
set -euo pipefail

ready=$(kubectl get deploy n8n-main -o jsonpath='{.status.readyReplicas}')
if [[ "$ready" != "2" ]]; then
  echo "::error::Expected 2 ready mains, found ${ready:-0}."
  exit 1
fi
if ! kubectl logs deploy/n8n-main --all-containers | grep -q 'license successfully activated'; then
  echo "::error::n8n-main did not activate the licence."
  exit 1
fi
echo "Both mains are ready and licensed."
