# 0031. Main and webhook processors run in external runner mode in queue mode

Date: 2026-11-10
PR: https://github.com/n8n-io/n8n-hosting/pull/289

## Context

In queue mode, n8n 2.x runs manual executions on main unless `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS` is `true`. The chart set it in every queue-mode install, so workers ran all executions and only workers carried the task-runner sidecar ([0014](0014-task-runners-on-by-default.md)).

n8n 3.0 always runs manual executions on workers in queue mode. It no longer reads the variable, and logs a warning when it is set.

The chart set `N8N_RUNNERS_MODE` only on pods with a sidecar. Main and the webhook processors in queue mode got nothing, so n8n fell back to internal mode. n8n 3.0 deprecates internal mode and logs a warning at startup whenever the mode resolves to it, including when it is unset. In queue mode neither pod starts a runner or a broker, so nothing on them uses the mode.

## Decision

The chart does not set `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS`. Chart 2.0 runs only n8n 3.x, so it needs no version check for the variable.

In queue mode, the chart sets `N8N_RUNNERS_MODE: external` on main and the webhook processors. They read no runner token, because n8n checks for one only when it starts a runner. There is no values key for it, because the topology decides it. An install that needs another mode on those pods sets it through `chartEnvOverrides`, under "One place to set anything, and a defined winner". As in [0024](0024-task-runner-broker-listens-on-localhost.md), the chart sets an n8n variable where the topology it renders needs one.

Standalone main keeps `taskRunners.mode` while it carries the sidecar, and nothing when `taskRunners.enabled` is false.

## Consequences

- Queue-mode main and webhook processor pods start without the offload or internal-mode warnings on n8n 3.x.
- Workers with `taskRunners.enabled: false` still run in internal mode and still log the warning, which is the warning such installs should see.
- An install that sets `N8N_RUNNERS_MODE` in `env.shared`, `env.main` or `env.webhookProcessor` in queue mode fails the render, and moves the value to `chartEnvOverrides`.
- An install that sets `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS` in `chartEnvOverrides` fails the render, because the override replaces nothing. It removes the entry.
