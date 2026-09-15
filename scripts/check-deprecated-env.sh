#!/usr/bin/env bash
#
# Fails if the chart renders an environment variable that n8n has deprecated.
#
# Render-only on purpose: no cluster, no licence, runs in seconds. That matters
# because some of these variables only appear under configurations CI cannot
# actually boot (S3 binary storage is licence-gated), so a runtime test would
# never reach them.
#
# Only variables the CHART emits belong here. n8n also warns about several
# variables because they are UNSET, asking operators to pin a default before it
# changes; those cannot be detected by grepping rendered output and are the
# deployer's call, not the chart's.
#
# When n8n deprecates another variable the chart sets, add it to DEPRECATED and
# add a scenario below that exercises the path emitting it.
set -uo pipefail

CHART="${1:-charts/n8n}"
KEY="--set secretRefs.env.N8N_ENCRYPTION_KEY=ci-placeholder-key-long-enough"

DEPRECATED=(
  "WEBHOOK_URL"
)

SCENARIOS=(
  "webhook-url|--set webhook.url=https://hooks.example.com"
  "ingress|--set ingress.enabled=true"
  "s3|--set s3.enabled=true --set s3.storage.mode=s3 --set s3.bucket.name=b --set s3.bucket.region=us-east-1 --set s3.auth.accessKeyId=A --set s3.auth.secretAccessKeySecret.name=s3-creds --set s3.auth.secretAccessKeySecret.key=secretKey"
  "queue-all-tiers|--set webhook.url=https://hooks.example.com --set redis.enabled=true --set worker.enabled=true --set webhookProcessor.enabled=true"
)

rc=0
for scenario in "${SCENARIOS[@]}"; do
  name="${scenario%%|*}"
  flags="${scenario#*|}"

  if ! out=$(helm template ci "$CHART" $KEY $flags 2>&1); then
    echo "render failed [$name]"
    echo "$out" | grep -i error | head -2
    rc=1
    continue
  fi

  for var in "${DEPRECATED[@]}"; do
    # Match only the positions where the chart can emit an env var name: an
    # env entry ("name: VAR"), a configMapKeyRef ("key: VAR"), or a ConfigMap
    # data key ("VAR:" at the start of a line). Values never match, so a URL
    # containing the deprecated name cannot false-positive, and N8N_WEBHOOK_URL
    # does not match WEBHOOK_URL. Here-string, not a pipe: with pipefail, grep
    # -q exiting early can SIGPIPE the writer and turn a hit into a miss.
    if grep -qE "((name|key): ${var}$)|(^[[:space:]]*${var}:)" <<< "$out"; then
      echo "FAIL [$name] chart renders deprecated env var: $var"
      rc=1
    fi
  done
done

if [ $rc -eq 0 ]; then
  echo "PASS: no deprecated env vars rendered"
fi
exit $rc
