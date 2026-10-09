#!/usr/bin/env bash
# Installs the Traefik and Prometheus Operator CRDs the example's extraObjects
# need, and the n8n-tls Secret its IngressRoute names. Only the CRDs are
# installed: the leg checks the chart's templating, not Traefik's routing.
set -euo pipefail

helm repo add traefik https://traefik.github.io/charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# The Traefik CRDs are too large for a Helm release Secret, so they are
# rendered and applied server-side rather than installed as a release.
helm template traefik-crds traefik/traefik-crds --version 1.18.0 | kubectl apply --server-side -f - > /dev/null
kubectl wait crd/ingressroutes.traefik.io --for=condition=Established --timeout=60s
helm install prometheus-operator-crds prometheus-community/prometheus-operator-crds \
  --version 32.0.1 --wait --timeout 120s

tls_dir=$(mktemp -d)
trap 'rm -rf "$tls_dir"' EXIT
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=n8n.example.com" \
  -keyout "$tls_dir/tls.key" -out "$tls_dir/tls.crt" 2> /dev/null
kubectl create secret tls n8n-tls --cert="$tls_dir/tls.crt" --key="$tls_dir/tls.key"
