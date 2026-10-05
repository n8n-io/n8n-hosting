#!/usr/bin/env bash
# Checks that cert-manager issued the example's certificate, and that
# ingress-nginx serves it and routes each path to the right n8n component.
set -euo pipefail

kubectl wait certificate/n8n-tls --for=condition=Ready --timeout=120s

tls_dir=$(mktemp -d)
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443 > /dev/null &
forward=$!
trap 'kill "$forward" 2> /dev/null; wait "$forward" 2> /dev/null; rm -rf "$tls_dir"' EXIT

kubectl get secret n8n-tls -o jsonpath='{.data.ca\.crt}' | base64 -d > "$tls_dir/ca.crt"

for attempt in $(seq 1 30); do
  nc -z localhost 8443 2> /dev/null && break
  if [[ "$attempt" == 30 ]]; then
    echo "::error::The port-forward to ingress-nginx did not open."
    exit 1
  fi
  sleep 1
done

# --cacert fails the request unless the controller serves the issued certificate.
request() {
  curl -sS --cacert "$tls_dir/ca.crt" --resolve n8n.example.com:8443:127.0.0.1 "$@"
}

status=$(request -o /dev/null -w '%{http_code}' https://n8n.example.com:8443/healthz)
if [[ "$status" != "200" ]]; then
  echo "::error::/healthz through the ingress returned ${status}, expected 200."
  exit 1
fi

headers=$(request -o /dev/null -D - https://n8n.example.com:8443/)
if ! grep -qi '^set-cookie: n8n_affinity=' <<< "$headers"; then
  echo "::error::The main ingress did not set the n8n_affinity sticky-session cookie."
  exit 1
fi

# ingress-nginx logs the upstream it chose for each request as
# [<namespace>-<service>-<port>], and names it even when that upstream fails,
# so the response has to come from n8n as well. A request is retried while
# the route settles, and the log line can lag the response. Logs are read
# into a variable so grep -q cannot SIGPIPE kubectl.
routed_to() {
  local path=$1 upstream=$2 expected_status=$3
  local status logs
  for _ in $(seq 1 15); do
    status=$(request -o /dev/null -w '%{http_code}' "https://n8n.example.com:8443${path}" || true)
    if [[ "$status" == "$expected_status" ]]; then
      logs=$(kubectl logs -n ingress-nginx deploy/ingress-nginx-controller)
      if grep -q "GET ${path} [^\"]*\" ${expected_status} .*\[${upstream}\]" <<< "$logs"; then
        return 0
      fi
    fi
    sleep 1
  done
  echo "Last status for ${path}: ${status}"
  return 1
}

if ! routed_to /healthz default-n8n-main-5678 200; then
  echo "::error::/healthz was not answered by n8n-main."
  exit 1
fi
# n8n answers an unregistered webhook with 404, where nginx's own failure
# would be a 502 or 503.
if ! routed_to /webhook/ci-routing-check default-n8n-webhook-processor-5678 404; then
  echo "::error::/webhook/ was not answered by n8n-webhook-processor."
  exit 1
fi

echo "TLS, sticky sessions and webhook routing work through ingress-nginx."
