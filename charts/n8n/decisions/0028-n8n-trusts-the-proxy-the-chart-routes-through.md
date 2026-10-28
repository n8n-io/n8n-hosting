# 0028. n8n trusts the proxy the chart routes through

Date: 2026-10-28
PR: https://github.com/n8n-io/n8n-hosting/pull/279

## Context

n8n takes the connecting address as the client's IP address unless `N8N_PROXY_HOPS` tells it how many proxies to trust. Then it reads the address from `X-Forwarded-For`. IP allowlists on Webhook nodes and the addresses n8n logs use that value.

The chart never set `N8N_PROXY_HOPS`. Behind an Ingress or an HTTPRoute, every request reached n8n from the ingress controller's or Gateway's pod, so every client had the same in-cluster address.

The chart knows when it puts a proxy in front of n8n, because it renders the Ingress or the route. It cannot see a proxy in front of that one, such as a CDN or a cloud load balancer.

## Decision

When `ingress.enabled` or `httpRoute.enabled` is true, the chart sets `N8N_PROXY_HOPS` to `1` on main and the webhook processors, the pods that take client traffic. Workers do not get it. With neither, the chart sets nothing and n8n's default applies.

There is no values key for the count. A deployment with more proxies raises it through `chartEnvOverrides`, which is the one place to replace a variable the chart sets. This sits under "One place to set anything, and a defined winner". As in [0024](0024-task-runner-broker-listens-on-localhost.md), the chart sets an n8n variable only where the topology it renders needs one.

## Consequences

Installs with an Ingress or an HTTPRoute see their clients' real addresses after the upgrade. An install behind a further proxy now sees that proxy's address until it raises the count. An install that sets `N8N_PROXY_HOPS` in `env` alongside an Ingress or an HTTPRoute fails the render, and moves the value to `chartEnvOverrides`. The change lands on 2.0, because it changes which address n8n records and trusts for every install with an ingress.

A route the chart does not render, such as a Traefik `IngressRoute` in `extraObjects`, gets no hop count. Those installs set `N8N_PROXY_HOPS` in `env`.
