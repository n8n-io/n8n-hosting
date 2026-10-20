# 0024. The task-runner broker listens on n8n's default address

Date: 2026-10-20
PR: https://github.com/n8n-io/n8n-hosting/pull/000

## Context

The task broker runs inside the n8n container, and the runner sidecar connects to it. n8n binds the broker to `127.0.0.1` by default. The 1.x chart set `N8N_RUNNERS_BROKER_LISTEN_ADDRESS` to `0.0.0.0` from `taskRunners.broker.listenAddress`.

The sidecar shares the pod's network namespace, so it reaches the broker on localhost. Nothing the chart deploys connects to the broker from outside the pod, so the topology does not need the override. With task runners on by default ([0014](0014-task-runners-on-by-default.md)), the override would apply to every worker.

## Decision

The chart does not set `N8N_RUNNERS_BROKER_LISTEN_ADDRESS`, so the broker listens where n8n puts it. `taskRunners.broker.listenAddress` retires. An install that runs a runner outside the pod sets the variable in `env.worker`, or in `env.main` in standalone mode.

This sits under "One place to set anything, and a defined winner": the chart sets a variable only where its own topology needs it, and the env maps are the one home for the rest.

## Consequences

- The broker listens on `127.0.0.1` only. The sidecar connects to `http://127.0.0.1:<port>`, the address the broker binds, rather than `localhost`, which can resolve to `::1` first.
- An install that sets `taskRunners.broker.listenAddress` fails to render, and the message names `env.worker` and `env.main`.
- `taskRunners.broker.port` stays, because the chart uses it to build the sidecar's broker URI.
