# shellcheck shell=bash
# Shared by the gateway-*.post.sh checks, which source it. It reaches an
# Envoy Gateway proxy through a port-forward and checks which n8n component
# answered a request.

# Port-forwards local port $2 to the Envoy proxy for Gateway $1 in
# gateway-system, once the proxy is available.
open_proxy() {
  local gateway=$1 port=$2 labels service forward attempt
  labels="gateway.envoyproxy.io/owning-gateway-name=${gateway},gateway.envoyproxy.io/owning-gateway-namespace=gateway-system"
  # Envoy Gateway creates the proxy Deployment after it accepts the Gateway,
  # and kubectl wait fails on a selector that matches nothing yet.
  for attempt in $(seq 1 60); do
    [[ -n "$(kubectl get deploy -n envoy-gateway-system -l "$labels" -o name)" ]] && break
    if [[ "$attempt" == 60 ]]; then
      echo "::error::Envoy Gateway did not create the proxy for ${gateway}."
      exit 1
    fi
    sleep 2
  done
  kubectl wait -n envoy-gateway-system deploy -l "$labels" --for=condition=Available --timeout=120s
  service=$(kubectl get service -n envoy-gateway-system -l "$labels" -o name)

  kubectl port-forward -n envoy-gateway-system "$service" "${port}:80" > /dev/null &
  forward=$!
  forwards+=("$forward")
  for attempt in $(seq 1 30); do
    nc -z localhost "$port" 2> /dev/null && return 0
    sleep 1
  done
  echo "::error::The port-forward to the proxy for ${gateway} did not open."
  exit 1
}

forwards=()
# wait returns 143 after kill, which set -e would turn into a failed check.
close_proxies() {
  local forward
  for forward in "${forwards[@]}"; do
    kill "$forward" 2> /dev/null || true
    wait "$forward" 2> /dev/null || true
  done
}
trap close_proxies EXIT

# The IPs of the pods behind one of the chart's Services.
backend_ips() {
  kubectl get endpointslices -l "kubernetes.io/service-name=$1" \
    -o jsonpath='{.items[*].endpoints[*].addresses[*]}'
}

# Succeeds when a request for $3 on host $2, through Gateway $1's proxy on
# local port $4, answers $6 and was served by Service $5. With $5 empty, it
# succeeds when Envoy found no route and answered itself. Envoy Gateway logs
# each request as JSON with the pod it sent it to as upstream_host, so the
# check matches that against the Service's pods. A request is retried while
# the route settles, and the log line can lag the response. Each grep reads
# from a variable, so grep -q cannot SIGPIPE a pipeline under pipefail.
routed_to() {
  local gateway=$1 host=$2 path=$3 port=$4 service=$5 expected_status=$6
  local labels status logs ip
  labels="gateway.envoyproxy.io/owning-gateway-name=${gateway},gateway.envoyproxy.io/owning-gateway-namespace=gateway-system"
  for _ in $(seq 1 15); do
    status=$(curl -sS --resolve "${host}:${port}:127.0.0.1" -o /dev/null -w '%{http_code}' "http://${host}:${port}${path}" || true)
    if [[ "$status" == "$expected_status" ]]; then
      logs=$(kubectl logs -n envoy-gateway-system -l "$labels" -c envoy --tail=-1)
      logs=$(grep -F "\"${path}\"" <<< "$logs" || true)
      if [[ -z "$service" ]]; then
        # NR is Envoy's response flag for a request that matched no route.
        grep -qF '"response_flags":"NR"' <<< "$logs" && return 0
        sleep 1
        continue
      fi
      for ip in $(backend_ips "$service"); do
        if grep -qF "\"upstream_host\":\"${ip}:" <<< "$logs"; then
          return 0
        fi
      done
    fi
    sleep 1
  done
  echo "Last status for ${host}${path}: ${status}"
  return 1
}

# Fails the check with $2 unless routed_to succeeds for the arguments in $1.
expect_route() {
  local message=$1
  shift
  if ! routed_to "$@"; then
    echo "::error::${message}"
    exit 1
  fi
}
