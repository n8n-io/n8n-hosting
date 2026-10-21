#!/usr/bin/env bash
# Checks that the Gateway accepts the chart's HTTPRoute, and that Envoy routes
# each path to the right n8n component.
set -euo pipefail
# shellcheck source-path=SCRIPTDIR
source "$(dirname "$0")/gateway-checks.sh"

kubectl wait httproute/n8n --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True --timeout=120s
kubectl wait httproute/n8n --for=jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}'=True --timeout=120s

open_proxy shared-gateway 8080
host=n8n.example.com

expect_route "/healthz was not answered by n8n-main." \
  shared-gateway "$host" /healthz 8080 n8n-main 200
# n8n answers an unregistered webhook with 404, where Envoy's own failure
# would be a 503.
expect_route "/webhook/ was not answered by n8n-webhook-processor." \
  shared-gateway "$host" /webhook/ci-routing-check 8080 n8n-webhook-processor 404
# A waiting path takes an execution ID, so the check names one that does not exist.
expect_route "/form-waiting/ was not answered by n8n-webhook-processor." \
  shared-gateway "$host" /form-waiting/999999 8080 n8n-webhook-processor 404
expect_route "/mcp/ was not answered by n8n-webhook-processor." \
  shared-gateway "$host" /mcp/ci-routing-check 8080 n8n-webhook-processor 404
# Test paths share a prefix with /mcp/ but not a whole segment, so they stay
# on main.
expect_route "/mcp-test/ was not answered by n8n-main." \
  shared-gateway "$host" /mcp-test/ci-routing-check 8080 n8n-main 404

echo "The HTTPRoute sends main and webhook traffic to the right components through Envoy Gateway."
