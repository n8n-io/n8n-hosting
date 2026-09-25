#!/usr/bin/env bash
# Shared by the S3 legs. n8n checks the bucket before it reports ready, so a
# healthy main in S3 mode has already reached the mock. This confirms it was
# the mock n8n configured, and that it logged no S3 errors.
set -euo pipefail

logs=$(kubectl logs deploy/n8n-main --all-containers)
if ! grep -q 'S3 binary storage configured: endpoint=http://s3mock:9090' <<< "$logs"; then
  echo "::error::n8n-main did not configure S3 binary storage against the mock."
  exit 1
fi
if grep -qi 's3.*error\|error.*s3' <<< "$logs"; then
  echo "::error::n8n-main logged an S3 error."
  grep -i 's3.*error\|error.*s3' <<< "$logs" | head -5
  exit 1
fi
echo "n8n-main stores binary data in the S3 mock."
