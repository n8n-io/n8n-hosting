#!/usr/bin/env bash
# n8n checks the S3 bucket before it reports ready, and S3 binary storage
# needs the licence, so healthy mains in S3 mode have already activated the
# licence and reached the bucket. This confirms each main configured the mock
# rather than another endpoint.
set -euo pipefail

pods=$(kubectl get pods -l app.kubernetes.io/component=main -o name)
if [[ -z "$pods" ]]; then
  echo "::error::No n8n-main pods found."
  exit 1
fi
# Logs are read into a variable first: piping kubectl into grep -q can end
# the pipeline with SIGPIPE, which pipefail reports as a failure.
for pod in $pods; do
  logs=$(kubectl logs "$pod" --all-containers)
  if ! grep -q 'S3 binary storage configured: endpoint=http://s3mock:9090' <<< "$logs"; then
    echo "::error::${pod} did not configure S3 binary storage against the mock."
    exit 1
  fi
done
echo "Every main stores binary data in the S3 mock."
