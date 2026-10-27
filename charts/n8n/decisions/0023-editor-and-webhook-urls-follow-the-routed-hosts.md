# 0023. The editor and webhook URLs follow the hosts the chart routes

Date: 2026-10-20
PR: https://github.com/n8n-io/n8n-hosting/pull/258
Supersedes: [0006](0006-public-urls-default-to-https.md)

## Context

n8n has two public URLs: `N8N_EDITOR_BASE_URL` for the editor, OAuth callbacks and links in emails, and `N8N_WEBHOOK_URL` for webhooks, forms and MCP. n8n builds every webhook, form and MCP URL it shows from the webhook URL, test URLs included. When the editor URL is not set, n8n uses the webhook URL. When the webhook URL is not set, or both are not set, n8n builds them from `N8N_HOST` and `N8N_PROTOCOL`, which default to `localhost` and `http`.

Under 0006, both URLs defaulted to `https://` and the first ingress host. Two setups got the wrong webhook URL: a plain-HTTP install that set `editor.url` still got an `https://` webhook URL, and an install with `editor.url` and no ingress got `http://localhost:5678`. `webhook.url` also stood in for the editor URL when the ingress was off.

A common setup keeps the editor on an internal host and takes webhooks on a public one. The chart could not route that: the webhook Ingress reused `ingress.hosts`, so the two hosts could not differ.

The chart cannot tell plain HTTP from TLS that ends before the ingress, at a cloud load balancer, a managed certificate or a CDN. Those installs leave `ingress.tls` empty and are served on `https://`.

## Decision

Each URL comes from the hosts the chart routes for it, and a value replaces it outright.

- The editor URL is `editor.url`, or else `https://` and the first editor host: the first ingress host, or the first `HTTPRoute` hostname.
- The webhook URL is `webhook.url`, or else `https://` and the first webhook host, or else the editor URL. Webhook hosts are `ingress.webhook.hosts` or `httpRoute.webhook.hostnames`.
- A webhook host carries the webhook paths only. The production paths go to the webhook processors when they run and to main otherwise. The test paths go to main. With webhook hosts set, the editor hosts send every path to main, so webhooks have one address: the one n8n shows.
- Without webhook hosts, webhooks share the editor hosts, and the chart sends the production webhook paths there to the webhook processors whenever they run.
- With no URL set and nothing routed, the chart sets neither variable.

The chart never derives a scheme from TLS settings, and it does not set `N8N_HOST` or `N8N_PROTOCOL`. This sits under "One place to set anything, and a defined winner": each URL has one value that wins, and otherwise follows the hosts the chart already routes.

## Consequences

- Plain-HTTP installs and installs without an ingress or `HTTPRoute` set `editor.url`, and `webhook.url` only when webhooks have a host of their own.
- `webhook.url` never sets the editor URL. An install that sets only `webhook.url` and routes nothing gets no editor URL from the chart, so n8n uses the webhook URL for it, as the chart did under 0006. `NOTES.txt` says so.
- `ingress.webhookProcessor` is retired for `ingress.webhook`, which no longer has an `enabled` switch. The webhook Ingress renders when `ingress.enabled` is true and webhook processors run or webhook hosts are set.
- A wildcard first host fails the render unless the matching URL value is set, because `https://*.example.com` is not an address n8n can use.
- `NOTES.txt` prints the editor URL the chart sets, so the install output and n8n agree.
- Deriving the scheme later would change URLs for upstream-TLS installs, so it needs a major version.
