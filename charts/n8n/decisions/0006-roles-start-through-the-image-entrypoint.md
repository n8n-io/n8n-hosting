# 0006. Every role starts through the image entrypoint

Date: 2026-10-10
PR: https://github.com/n8n-io/n8n-hosting/pull/241

## Context

The n8n image sets `ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]`. The script trusts the CA certificates in `/opt/custom-certificates` when that directory exists, then runs `exec n8n "$@"`. The main container sets neither `command` nor `args`, so it has always started this way.

The worker and webhook-processor containers set `command: ["n8n"]`. In Docker Compose, `command` sets only the arguments and keeps the entrypoint. In Kubernetes, `command` replaces the entrypoint. So workers and webhook processors skipped the certificate import, and ran with n8n as PID 1 instead of tini. With a private CA, main could reach a service that workers could not.

## Decision

n8n containers never set `command`. Each role passes only `args`: `[worker, --concurrency=N]` for workers and `[webhook]` for webhook processors. The image entrypoint passes these to `n8n`.

This sits under "Portable primitives with portable defaults": the image already defines how n8n starts, so the chart uses that and does not define a second way.

## Consequences

- Workers and webhook processors trust `/opt/custom-certificates` in the same way main does.
- tini is PID 1 in every role. It forwards SIGTERM to n8n, so graceful shutdown is unchanged. It also reaps orphaned child processes, which n8n as PID 1 did not.
- With no `/opt/custom-certificates` directory, the n8n process gets the same arguments and environment as before.
- A custom image that replaces the n8n ENTRYPOINT must pass its arguments on to `n8n`. If it does not, worker and webhook-processor pods do not start their role. Images built `FROM n8nio/n8n` that keep the inherited ENTRYPOINT are not affected.
