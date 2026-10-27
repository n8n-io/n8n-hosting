# 0013. Worker probes use the queue health endpoint

Date: 2026-10-15
PR: https://github.com/n8n-io/n8n-hosting/pull/233
Superseded by: [0027](0027-worker-probes-run-a-command-or-the-health-endpoint.md)

## Context

Workers serve no UI or API, so the chart probed them with `pgrep -f 'n8n worker'` in a shell. The shell's own command line contains that string, so `pgrep` always found a match and the probe always passed. A worker that had lost Redis or the database stayed Ready, and a rollout went ahead while new workers were still waiting on the migration lock.

n8n starts an HTTP server on a worker when `QUEUE_HEALTH_CHECK_ACTIVE` is set. `/healthz` answers once the process is serving. `/healthz/readiness` answers 503 until the worker is connected to the database, migrations have finished and Redis is connected. The server starts only after migrations, so nothing listens while a worker waits on the migration lock.

## Decision

`redis.healthCheck.enabled` defaults to `true`, so workers serve the health endpoint on `redis.healthCheck.port`. Worker liveness probes `/healthz` and readiness probes `/healthz/readiness`. A startup probe on `/healthz` with the same budget as main's (30 attempts, 10 seconds apart) holds off liveness during a slow first start or a wait on the migration lock. The task-runner sidecar needs no startup probe because its launcher answers within a second; the worker answers only after migrations.

`probes.worker.liveness.type` and `readiness.type` have no default. When a type is not set, the chart picks one: `exec` when a `command` is set, otherwise `httpGet` when the health endpoint is on, otherwise `exec` with the `pgrep` process check. An `exec` probe with no command also runs the process check. Every values file that rendered before keeps rendering, so the change ships as a fix: installs on default values move to the health endpoint, and overrides keep the probe they asked for.

One combination stops the render: `type: httpGet` with `redis.healthCheck.enabled: false`. It never worked, because the chart used to fall back to `exec` without saying so. This follows "Fail loudly, never silently".

Every worker probe field, the startup probe included, sits under `probes.worker`, so users can tune or disable each probe without patching the template. The chart sets the health variables on workers only. n8n reads them in the worker process and nowhere else.

## Consequences

- With default values, upgrading rolls the workers. From then on, a worker without its database or Redis drops out of Ready, and a worker whose health endpoint is not up within the startup budget is restarted.
- Installs that switch the health endpoint off, including values files copied whole from an older chart, keep the process check. It cannot fail, so those workers get no real health check until they remove `redis.healthCheck.enabled: false`.
- Installs that set a probe `command` without a type now also get the HTTP startup probe. They can set `probes.worker.startup.enabled: false` to drop it.
- The worker health port must not clash with another port in the worker container, such as the task-runner broker on 5679.
