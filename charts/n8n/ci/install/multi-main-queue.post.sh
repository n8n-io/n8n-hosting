#!/usr/bin/env bash
# Checks both mains are up in multi-main mode, reach the S3 mock through the
# NetworkPolicy, and have an active licence. The mains share one database, so
# only the first to start activates the licence.
# A main that finds the licence already stored, as every main does after an
# upgrade, logs the stored cert's state instead, which has to be valid.
set -euo pipefail

ready=$(kubectl get deploy n8n-main -o jsonpath='{.status.readyReplicas}')
if [[ "$ready" != "2" ]]; then
  echo "::error::Expected 2 ready mains, found ${ready:-0}."
  exit 1
fi

# Each main calls the mock from inside the pod, so the request leaves through
# the NetworkPolicy's egress rules. Any HTTP response means it got through.
for pod in $(kubectl get pods -l app.kubernetes.io/component=main -o name); do
  if ! kubectl exec "$pod" -c n8n-main -- node -e \
    "fetch('http://s3mock:9090/n8n-ci', {method: 'HEAD', signal: AbortSignal.timeout(5000)}).then(() => process.exit(0), () => process.exit(1))"; then
    echo "::error::${pod} could not reach the S3 mock on port 9090."
    exit 1
  fi
done

# Logs are read into a variable first: piping kubectl into grep -q can end
# the pipeline with SIGPIPE, which pipefail reports as a failure.
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
