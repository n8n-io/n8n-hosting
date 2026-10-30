#!/usr/bin/env bash
# Installs Envoy Gateway and shared-gateway, as gateway-httproute.pre.sh does,
# and adds public-gateway, which examples/gateway-webhook-host.yaml attaches
# its webhook route to.
set -euo pipefail

bash "$(dirname "$0")/gateway-httproute.pre.sh"

kubectl apply -f - <<'GATEWAY'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: public-gateway
  namespace: gateway-system
spec:
  gatewayClassName: envoy-gateway
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
GATEWAY

kubectl wait -n gateway-system gateway/public-gateway --for=condition=Accepted --timeout=120s
