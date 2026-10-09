#!/usr/bin/env bash
# Checks the API server accepted each extraObjects entry under the name tpl
# gave it, and that tpl filled in the release's names rather than passing the
# template text through.
set -euo pipefail

kubectl get ingressroute.traefik.io n8n
service=$(kubectl get ingressroute.traefik.io n8n -o jsonpath='{.spec.routes[0].services[0].name}')
if [[ "$service" != "n8n-main" ]]; then
  echo "::error::The IngressRoute points at '${service}', expected n8n-main."
  exit 1
fi

kubectl get prometheusrule n8n-alerts
summary=$(kubectl get prometheusrule n8n-alerts -o jsonpath='{.spec.groups[0].rules[0].annotations.summary}')
# shellcheck disable=SC2016 # The literal {{ $labels.deployment }} is what Prometheus needs.
if [[ "$summary" != '{{ $labels.deployment }} has had no available replicas for 5 minutes' ]]; then
  echo "::error::The PrometheusRule summary is '${summary}', expected a literal {{ \$labels.deployment }}."
  exit 1
fi

main=$(kubectl get configmap n8n-endpoints -o jsonpath='{.data.main}')
if [[ "$main" != "http://n8n-main.default.svc:5678" ]]; then
  echo "::error::The n8n-endpoints ConfigMap has main=${main}, expected http://n8n-main.default.svc:5678."
  exit 1
fi

echo "All three extraObjects entries were accepted and templated."
