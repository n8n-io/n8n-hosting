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
for pod in $pods; do
  if ! kubectl logs "$pod" --all-containers | grep -q 'S3 binary storage configured: endpoint=http://s3mock:9090'; then
    echo "::error::${pod} did not configure S3 binary storage against the mock."
    exit 1
  fi
done
echo "Every main stores binary data in the S3 mock."
