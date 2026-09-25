#!/usr/bin/env bash
# Installs ingress-nginx and cert-manager, which examples/https-ingress.yaml
# expects the cluster to run. CI cannot reach Let's Encrypt, so a CA issuer
# backed by a self-signed root stands in under the name the example uses.
set -euo pipefail

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io

helm install ingress-nginx ingress-nginx/ingress-nginx --version 4.15.1 \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=ClusterIP \
  --wait --timeout 300s

helm install cert-manager jetstack/cert-manager --version v1.21.2 \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true \
  --wait --timeout 300s

# The cert-manager webhook can refuse requests for a few seconds after its
# pod reports ready.
for attempt in $(seq 1 30); do
  if kubectl apply -f - <<'ISSUERS'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ci-selfsigned
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ci-root-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: ci-root-ca
  secretName: ci-root-ca
  issuerRef:
    name: ci-selfsigned
    kind: ClusterIssuer
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  ca:
    secretName: ci-root-ca
ISSUERS
  then
    break
  fi
  if [[ "$attempt" == 30 ]]; then
    echo "::error::cert-manager did not accept the CI issuers."
    exit 1
  fi
  sleep 2
done

kubectl wait -n cert-manager certificate/ci-root-ca --for=condition=Ready --timeout=120s
kubectl wait clusterissuer/letsencrypt-prod --for=condition=Ready --timeout=60s
