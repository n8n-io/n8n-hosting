#!/usr/bin/env bash
# Checks that the Gateway accepts the chart's HTTPRoute, and that Envoy routes
# each path to the right n8n component.
set -euo pipefail

kubectl wait httproute/n8n --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True --timeout=120s
kubectl wait httproute/n8n --for=jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}'=True --timeout=120s

proxy_labels=gateway.envoyproxy.io/owning-gateway-name=shared-gateway,gateway.envoyproxy.io/owning-gateway-namespace=gateway-system
# Envoy Gateway creates the proxy Deployment after it accepts the Gateway, and
# kubectl wait fails on a selector that matches nothing yet.
for attempt in $(seq 1 60); do
  [[ -n "$(kubectl get deploy -n envoy-gateway-system -l "$proxy_labels" -o name)" ]] && break
  if [[ "$attempt" == 60 ]]; then
    echo "::error::Envoy Gateway did not create the proxy Deployment."
    exit 1
  fi
  sleep 2
done
kubectl wait -n envoy-gateway-system deploy -l "$proxy_labels" --for=condition=Available --timeout=120s
proxy_service=$(kubectl get service -n envoy-gateway-system -l "$proxy_labels" -o name)

kubectl port-forward -n envoy-gateway-system "$proxy_service" 8080:80 > /dev/null &
forward=$!
# wait returns 143 after kill, which set -e would turn into a failed check.
trap 'kill "$forward" 2> /dev/null || true; wait "$forward" 2> /dev/null || true' EXIT

for attempt in $(seq 1 30); do
  nc -z localhost 8080 2> /dev/null && break
  if [[ "$attempt" == 30 ]]; then
    echo "::error::The port-forward to the Envoy proxy did not open."
    exit 1
  fi
  sleep 1
done

request() {
  curl -sS --resolve n8n.example.com:8080:127.0.0.1 "$@"
}

# The IPs of the pods behind one of the chart's Services.
backend_ips() {
  kubectl get endpointslices -l "kubernetes.io/service-name=$1" \
    -o jsonpath='{.items[*].endpoints[*].addresses[*]}'
}

# Envoy Gateway logs each request as JSON with the pod it sent it to as
# upstream_host, so the check matches that against the Service's pods. A
# request is retried while the route settles, and the log line can lag the
# response. Each grep reads from a variable, so grep -q cannot SIGPIPE a
# pipeline under pipefail.
routed_to() {
  local path=$1 service=$2 expected_status=$3
  local status logs ip
  for _ in $(seq 1 15); do
    status=$(request -o /dev/null -w '%{http_code}' "http://n8n.example.com:8080${path}" || true)
    if [[ "$status" == "$expected_status" ]]; then
      logs=$(kubectl logs -n envoy-gateway-system -l "$proxy_labels" -c envoy --tail=-1)
      logs=$(grep -F "\"${path}\"" <<< "$logs" || true)
      for ip in $(backend_ips "$service"); do
        if grep -qF "\"upstream_host\":\"${ip}:" <<< "$logs"; then
          return 0
        fi
      done
    fi
    sleep 1
  done
  echo "Last status for ${path}: ${status}"
  return 1
}

if ! routed_to /healthz n8n-main 200; then
  echo "::error::/healthz was not answered by n8n-main."
  exit 1
fi
# n8n answers an unregistered webhook with 404, where Envoy's own failure
# would be a 503.
if ! routed_to /webhook/ci-routing-check n8n-webhook-processor 404; then
  echo "::error::/webhook/ was not answered by n8n-webhook-processor."
  exit 1
fi
# A waiting path takes an execution ID, so the check names one that does not exist.
if ! routed_to /form-waiting/999999 n8n-webhook-processor 404; then
  echo "::error::/form-waiting/ was not answered by n8n-webhook-processor."
  exit 1
fi
if ! routed_to /mcp/ci-routing-check n8n-webhook-processor 404; then
  echo "::error::/mcp/ was not answered by n8n-webhook-processor."
  exit 1
fi
# Test paths share a prefix with /mcp/ but not a whole segment, so they stay
# on main.
if ! routed_to /mcp-test/ci-routing-check n8n-main 404; then
  echo "::error::/mcp-test/ was not answered by n8n-main."
  exit 1
fi

echo "The HTTPRoute sends main and webhook traffic to the right components through Envoy Gateway."
