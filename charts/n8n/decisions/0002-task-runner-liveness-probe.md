# 0002. The task-runner sidecar has a liveness probe only

Date: 2026-10-04
PR: https://github.com/n8n-io/n8n-hosting/pull/223

## Context

The task-runner sidecar runs the launcher, which starts the JavaScript and Python runners when tasks arrive. The sidecar had no probes, so a launcher that crashed or hung stayed in place, and Code nodes failed until someone restarted the pod.

The launcher serves a health endpoint, `/healthz` on port `5680`, and answers it whatever its runners are doing. The launcher already restarts a runner that stops responding, and n8n aborts a task whose runner stops responding. A probe on the sidecar only needs to catch the launcher itself.

## Decision

The sidecar has a liveness probe on the launcher's health endpoint, and no startup or readiness probe.

- **No startup probe.** The launcher serves `/healthz` within a second of starting, before it does any slow work, and the liveness probe's initial delay and failure threshold already cover start-up.
- **No readiness probe.** The n8n container's own readiness probe decides whether the pod receives traffic.

The defaults match the liveness probe n8n Cloud runs on the same sidecar: `initialDelaySeconds: 5`, `periodSeconds: 10`, `timeoutSeconds: 30` and `failureThreshold: 6`. These are generous enough for most installs, and the 30 second timeout keeps the probe passing when the sidecar is CPU-throttled.

Every field is exposed under `taskRunners.probes.liveness`, so users can tune or disable the probe without patching the templates. This follows "Consumable as a subchart without a fork".

## Consequences

- A runner that is busy or CPU-throttled does not fail the probe. On kind, the probe answered every check while a Code node held the sidecar at its CPU limit for 200 seconds.
- With the defaults, Kubernetes restarts a hung launcher about 3 minutes after it stops responding. Users who want faster detection can shorten `timeoutSeconds` or `failureThreshold`.
- Existing installs with task runners gain the probe on upgrade, and their pods roll once. Setting `taskRunners.probes.liveness.enabled: false` renders the sidecar as before.
