#!/usr/bin/env bash
# Checks that each Gateway accepts its route, that the editor host sends every
# path to main, and that the webhook host carries only the webhook paths.
set -euo pipefail
source "$(dirname "$0")/gateway-checks.sh"

for route in n8n n8n-webhook; do
  kubectl wait "httproute/${route}" --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True --timeout=120s
  kubectl wait "httproute/${route}" --for=jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}'=True --timeout=120s
done

open_proxy shared-gateway 8080
open_proxy public-gateway 8081
editor=n8n.internal.example.com
hooks=hooks.example.com

expect_route "/healthz on the editor host was not answered by n8n-main." \
  shared-gateway "$editor" /healthz 8080 n8n-main 200
# With a webhook host, the editor host sends webhook paths to main too. Main
# does not serve production webhooks in this example, so it answers with the
# editor page.
expect_route "/webhook/ on the editor host was not answered by n8n-main." \
  shared-gateway "$editor" /webhook/ci-routing-check 8080 n8n-main 200

expect_route "/webhook/ on the webhook host was not answered by n8n-webhook-processor." \
  public-gateway "$hooks" /webhook/ci-routing-check 8081 n8n-webhook-processor 404
expect_route "/mcp/ on the webhook host was not answered by n8n-webhook-processor." \
  public-gateway "$hooks" /mcp/ci-routing-check 8081 n8n-webhook-processor 404
expect_route "/webhook-test/ on the webhook host was not answered by n8n-main." \
  public-gateway "$hooks" /webhook-test/ci-routing-check 8081 n8n-main 404
# The editor is not reachable on the webhook host, so Envoy answers 404
# itself, with no upstream.
expect_route "/ on the webhook host was routed somewhere." \
  public-gateway "$hooks" / 8081 "" 404

echo "The editor and webhook routes send traffic to the right components through Envoy Gateway."
