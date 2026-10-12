# 0006. Public URLs default to https and are overridden by value

Date: 2026-10-09
PR: https://github.com/n8n-io/n8n-hosting/pull/000

## Context

n8n needs two public URLs: `N8N_WEBHOOK_URL` for webhooks and `N8N_EDITOR_BASE_URL` for the editor, OAuth redirects and links in emails. With ingress enabled, the chart builds both from the first ingress host with `https://`. An install served over plain HTTP gets URLs that don't work. `webhook.url` could already replace the webhook URL, but nothing in values could replace the editor URL.

One option was to choose the scheme from `ingress.tls`. The chart cannot tell plain HTTP from TLS that ends before the ingress, at a cloud load balancer, a managed certificate or a CDN. Those installs leave `ingress.tls` empty and are correct on `https://` today. Deriving the scheme would move them to `http://` and break their webhook and OAuth URLs.

## Decision

The chart keeps `https://` and the first ingress host as the default for both URLs. Each URL has one value that replaces it outright: `webhook.url` and `editor.url`. The chart does not inspect TLS settings to choose a scheme.

This sits under "One place to set anything, and a defined winner". For `N8N_EDITOR_BASE_URL` the order is `editor.url`, then the ingress host, then `webhook.url` when ingress is off.

## Consequences

- Installs that do not set `editor.url` render as before.
- Plain-HTTP installs set `webhook.url` and `editor.url`. The README shows both.
- The schema rejects an `editor.url` without `http://` or `https://`.
- Deriving the scheme later would change URLs for upstream-TLS installs, so it needs a major version.
