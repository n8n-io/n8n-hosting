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

# Logs are read into a variable first: piping kubectl into grep -q can end
# the pipeline with SIGPIPE, which pipefail reports as a failure.
for _ in $(seq 1 15); do
  for pod in $(kubectl get pods -l app.kubernetes.io/component=main -o name); do
    logs=$(kubectl logs "$pod" --all-containers)
    if grep -q 'license successfully activated' <<< "$logs"; then
      echo "Both mains are ready, and ${pod} activated the licence."
      exit 0
    fi
  done
  sleep 2
done
echo "::error::No n8n-main pod activated the licence."
exit 1
