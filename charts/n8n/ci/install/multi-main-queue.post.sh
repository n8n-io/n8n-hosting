#!/usr/bin/env bash
# Checks both mains are up in multi-main mode, store binary data in the S3
# mock, and have an active licence. The mains share one database, so only
# the first to start activates the licence.
# A main that finds the licence already stored, as every main does after an
# upgrade, logs the stored cert's state instead, which has to be valid.
set -euo pipefail

ready=$(kubectl get deploy n8n-main -o jsonpath='{.status.readyReplicas}')
if [[ "$ready" != "2" ]]; then
  echo "::error::Expected 2 ready mains, found ${ready:-0}."
  exit 1
fi

# n8n checks the bucket before it reports ready, so a ready main that logs
# the mock's endpoint has reached it through the NetworkPolicy. Logs are read
# into a variable first: piping kubectl into grep -q can end the pipeline
# with SIGPIPE, which pipefail reports as a failure.
for pod in $(kubectl get pods -l app.kubernetes.io/component=main -o name); do
  logs=$(kubectl logs "$pod" --all-containers)
  if ! grep -q 'S3 binary storage configured: endpoint=http://s3mock:9090' <<< "$logs"; then
    echo "::error::${pod} did not configure S3 binary storage against the mock."
    exit 1
  fi
done

for _ in $(seq 1 15); do
  for pod in $(kubectl get pods -l app.kubernetes.io/component=main -o name); do
    logs=$(kubectl logs "$pod" --all-containers)
    if grep -q 'license successfully activated' <<< "$logs"; then
      echo "Both mains are ready, and ${pod} activated the licence."
      exit 0
    fi
    if grep -q '\[license SDK\] cert state: .* isValid=true ' <<< "$logs"; then
      echo "Both mains are ready, and ${pod} loaded the stored licence."
      exit 0
    fi
  done
  sleep 2
done
echo "::error::No n8n-main pod activated or loaded the licence."
exit 1
