# 0013. Worker probes use the queue health endpoint

Date: 2026-10-15
PR: https://github.com/n8n-io/n8n-hosting/pull/233

## Context

Workers serve no UI or API, so the chart probed them with `pgrep -f 'n8n worker'` in a shell. The shell's own command line contains that string, so `pgrep` always found a match and the probe always passed. A worker that had lost Redis or the database stayed Ready, and a rollout went ahead while new workers were still waiting on the migration lock.

n8n starts an HTTP server on a worker when `QUEUE_HEALTH_CHECK_ACTIVE` is set. `/healthz` answers once the process is serving. `/healthz/readiness` answers 503 until the worker is connected to the database, migrations have finished and Redis is connected. The server starts only after migrations, so nothing listens while a worker waits on the migration lock.

## Decision

`redis.healthCheck.enabled` defaults to `true`, so workers serve the health endpoint on `redis.healthCheck.port`. Worker liveness probes `/healthz` and readiness probes `/healthz/readiness`. A startup probe on `/healthz` with the same budget as main's (30 attempts, 10 seconds apart) holds off liveness during a slow first start or a wait on the migration lock. The task-runner sidecar needs no startup probe because its launcher answers within a second; the worker answers only after migrations.

A worker liveness or readiness probe is HTTP against the health endpoint, or `exec` running the `command` the user sets, and nothing else. The `command` alone decides which: set means exec, empty means HTTP. There is no `type` key, so a values file cannot ask for HTTP and set a command the probe would ignore. There is no process check, so the chart never renders a probe that cannot fail.

With `redis.healthCheck.enabled: false`, an enabled worker probe with no `command` has nothing to check, and the render fails. The message names the three fixes: turn the health endpoint back on, set a `command`, or disable that probe. This follows "Fail loudly, never silently".

Chart 1.x keeps `type` and the process check, so that every 1.x values file keeps rendering and the move to the health endpoint ships there as a fix. Chart 2.0 lists `probes.worker.liveness.type` and `probes.worker.readiness.type` in `n8n.retiredKeys` (decision 0020).

Every worker probe field, the startup probe included, sits under `probes.worker`, so users can tune or disable each probe without patching the template. The chart sets the health variables on workers only. n8n reads them in the worker process and nowhere else.

## Consequences

- With default values, upgrading rolls the workers. From then on, a worker without its database or Redis drops out of Ready, and a worker whose health endpoint is not up within the startup budget is restarted.
- A values file that sets either `type` key fails the render until the key is removed. A values file copied whole from chart 1.16 or earlier sets both, together with `redis.healthCheck.enabled: false` and the `pgrep` command.
- The chart does not inspect a `command`. A user who keeps the 1.x `pgrep` command keeps a probe that always passes, so `UPGRADING.md` tells them to remove it.
- Installs that set a probe `command` with the health endpoint on also get the HTTP startup probe. They can set `probes.worker.startup.enabled: false` to drop it.
- The worker health port must not clash with another port in the worker container, such as the task-runner broker on 5679.
