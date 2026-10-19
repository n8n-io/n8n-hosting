# 0006. n8n has one public address, which defaults to https

Date: 2026-10-16
PR: https://github.com/n8n-io/n8n-hosting/pull/258

## Context

n8n needs two public URLs: `N8N_EDITOR_BASE_URL` for the editor, OAuth redirects and links in emails, and `N8N_WEBHOOK_URL` for webhooks and forms. When neither is set, n8n builds a fallback from `N8N_HOST` and `N8N_PROTOCOL`, which default to `localhost` and `http`.

The chart routes the editor and webhooks through the same hosts. The webhook processor Ingress reuses `ingress.hosts` and splits traffic by path, and the `HTTPRoute` does the same with `httpRoute.hostnames`. So the two URLs only differ when webhooks arrive somewhere the chart does not route, such as a separate load balancer or API gateway.

The chart cannot tell plain HTTP from TLS that ends before the ingress, at a cloud load balancer, a managed certificate or a CDN. Those installs leave `ingress.tls` empty and are served on `https://`.

## Decision

n8n has one public address, and the chart sets both URLs from it.

- The editor URL is `editor.url`, or else `https://` and the first host the chart routes: the first ingress host, or the first `HTTPRoute` hostname.
- The webhook URL is `webhook.url`, or else the editor URL.
- With no URL set and nothing routed, the chart sets neither variable.

The chart never derives a scheme from TLS settings, and it does not set `N8N_HOST` or `N8N_PROTOCOL`. This sits under "One place to set anything, and a defined winner": the address has one home, `editor.url`, and `webhook.url` exists only for webhooks the chart does not route.

## Consequences

- Plain-HTTP installs and installs without an ingress or `HTTPRoute` set `editor.url` alone. Webhooks follow it.
- `webhook.url` never sets the editor URL. An install that sets only `webhook.url` and routes nothing gets no editor URL, and `NOTES.txt` warns about it.
- `NOTES.txt` prints the editor URL the chart sets, so the install output and n8n agree.
- The schema rejects an `editor.url` without `http://` or `https://`.
- Deriving the scheme later would change URLs for upstream-TLS installs, so it needs a major version.
