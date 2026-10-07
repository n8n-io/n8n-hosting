# 0004. Worker probes use the queue health endpoint

Date: 2026-10-07
PR: https://github.com/n8n-io/n8n-hosting/pull/000

## Context

Workers serve no UI or API, so the chart probed them with `pgrep -f 'n8n worker'` in a shell. The shell's own command line contains that string, so `pgrep` always found a match and the probe always passed. A worker that had lost Redis or the database stayed Ready, and a rollout went ahead while new workers were still waiting on the migration lock.

n8n starts an HTTP server on a worker when `QUEUE_HEALTH_CHECK_ACTIVE` is set. `/healthz` answers once the process is serving. `/healthz/readiness` answers 503 until the worker is connected to the database, migrations have finished and Redis is connected. The server starts only after migrations, so nothing listens while a worker waits on the migration lock.

## Decision

`redis.healthCheck.enabled` defaults to `true`, so workers serve the health endpoint on `redis.healthCheck.port`. Worker liveness probes `/healthz`. Worker readiness probes `/healthz/readiness`. A startup probe on `/healthz` with the same budget as main's (30 attempts, 10 seconds apart) holds off liveness during a slow first start or a wait on the migration lock. The task-runner sidecar has no startup probe because its launcher answers within a second. The worker answers only after migrations, so it needs one. Every worker probe field, the startup probe included, sits under `probes.worker`, so users can tune or disable each probe without patching the template.

`probes.worker.*.type: exec` with a `command` still runs an exec probe instead. Three combinations stop the render with the fix named: an HTTP probe with the health endpoint switched off, an exec probe with no command, and a command on an HTTP probe. This sits under "Fail loudly, never silently": the old fallback from `httpGet` to `exec` rendered a probe that could not fail.

The chart sets the health variables on workers only. n8n reads them in the worker process and nowhere else.

## Consequences

- With default values, upgrading rolls the workers. From then on, a worker without its database or Redis drops out of Ready, and a worker stuck past the startup budget is restarted.
- A values file copied whole from an older chart sets `redis.healthCheck.enabled: false` and `type: exec`, and keeps the old exec probes. Remove those keys to take the new defaults.
- A values file that sets only `redis.healthCheck.enabled: false`, only `type: exec`, or only `command` now fails to render. Set `type: exec` together with a `command`, or remove the keys.
- The worker health port must not clash with another port in the worker container, such as the task-runner broker on 5679.
