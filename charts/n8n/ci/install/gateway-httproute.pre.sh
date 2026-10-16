#!/usr/bin/env bash
# Installs Envoy Gateway, which brings the Gateway API CRDs, and the Gateway
# that examples/gateway-httproute.yaml attaches to.
set -euo pipefail

helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm --version v1.9.2 \
  --namespace envoy-gateway-system --create-namespace \
  --wait --timeout 300s

kubectl wait -n envoy-gateway-system deploy/envoy-gateway --for=condition=Available --timeout=120s

kubectl create namespace gateway-system
kubectl apply -f - <<'GATEWAY'
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-gateway
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shared-gateway
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

# kind has no load balancer, so the Gateway is never Programmed with an
# address. Accepted is enough: Envoy Gateway still runs the proxy, and
# gateway-httproute.post.sh reaches it with a port-forward.
kubectl wait -n gateway-system gateway/shared-gateway --for=condition=Accepted --timeout=120s
