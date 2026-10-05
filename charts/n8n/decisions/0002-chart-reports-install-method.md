# 0002. The chart tells n8n it installed it

Date: 2026-10-05
PR: https://github.com/n8n-io/n8n-hosting/pull/224

## Context

n8n's telemetry reports a deployment type, but nothing says which artefact installed n8n. A chart install looks the same as a Docker Compose install or a hand-written manifest. So we can't tell how many people run the chart, or which chart versions are still in use.

n8n reads `N8N_INSTALL_METHOD` and sends it with the telemetry it already sends. Older n8n versions ignore the variable. Charts that wrap this one, such as marketplace listings, need to report under their own name.

## Decision

The chart sets `N8N_INSTALL_METHOD` to `helm-chart/<chart version>` on every component. The value comes from `config.installMethod`. When that value is empty, the chart uses its own name and version. A wrapping chart sets `config.installMethod` to its own name and version.

The value has its own key rather than an entry in `config.extraEnv`. This follows "one place to set anything, and a defined winner". An override through `extraEnv` would put two entries with the same name in the pod spec, and server-side apply and strategic merge patches do not handle that reliably.

## Consequences

- Upgrading to the release that adds this restarts every n8n pod once, because the ConfigMap checksum changes.
- The value carries the chart version, so it changes with every chart release. Most chart releases already restart pods because they change `appVersion`.
- The value names the artefact and its version. It carries nothing about the install itself.
- To stop sending telemetry, set `N8N_DIAGNOSTICS_ENABLED` to `false` in `config.extraEnv`. That stops this value along with the rest.
