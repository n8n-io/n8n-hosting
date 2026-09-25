#!/usr/bin/env bash
# Checks both mains are up in multi-main mode and the licence activated. The
# mains share one database, so only the first to start activates the licence;
# the other finds it already stored and logs nothing at the default level.
set -euo pipefail

ready=$(kubectl get deploy n8n-main -o jsonpath='{.status.readyReplicas}')
if [[ "$ready" != "2" ]]; then
  echo "::error::Expected 2 ready mains, found ${ready:-0}."
  exit 1
fi
for pod in $(kubectl get pods -l app.kubernetes.io/component=main -o name); do
  if kubectl logs "$pod" --all-containers | grep -q 'license successfully activated'; then
    echo "Both mains are ready, and ${pod} activated the licence."
    exit 0
  fi
done
echo "::error::No n8n-main pod activated the licence."
exit 1
