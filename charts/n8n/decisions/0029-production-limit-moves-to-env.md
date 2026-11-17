# 0029. The production concurrency limit is set in env

Date: 2026-10-29
PR: https://github.com/n8n-io/n8n-hosting/pull/283
Supersedes: [0012](0012-env-as-per-component-maps.md), for worker concurrency and the removed `extraEnv` lists only

## Context

The chart had two values for a worker's concurrency. `queueMode.workerConcurrency` renders the worker's `--concurrency` flag. `executions.concurrency.productionLimit` renders `N8N_CONCURRENCY_PRODUCTION_LIMIT`. In queue mode, n8n turns off concurrency control on main and uses the variable as each worker's concurrency, ignoring the flag. Decision 0012 made the render fail when both were set.

That check is not a retired key, so the upgrade test could not tell it apart from a setting retired without a named replacement. Decision 0012 also retired the `extraEnv` lists, `webhook.timeout` and three `secretRefs.env` keys with checks of its own, outside the `n8n.retiredKeys` list from decision 0020. Those checks failed on a non-empty list only.

## Decision

`executions.concurrency.productionLimit` is retired. It is an n8n product setting, not part of the deployment's shape, and the chart sets n8n's environment only where the shape needs it. Users set `N8N_CONCURRENCY_PRODUCTION_LIMIT` in `env.worker` in queue mode, or in `env.main` in standalone mode. `queueMode.workerConcurrency` stays, because the chart renders the worker's command line. The render still fails when a worker gets both the flag and the variable. This sits under "One place to set anything, and a defined winner".

Under decision 0020, the settings decision 0012 retired move into `n8n.retiredKeys`, and this key joins them. They fail like every other retired key: when the path is present, whatever its value, so an empty `extraEnv` list fails too. The upgrade test fails on any reason an unmigrated values file fails that `n8n.retiredKeys` does not explain.

## Consequences

- Installs that set `productionLimit` move it to `env.worker` or `env.main`. Workers that ran at `productionLimit` keep that concurrency once it moves.
- A 1.x values file that carries empty `extraEnv` or `extraEnvFrom` lists must delete them.
- `executions.timeout`, `executions.timeoutMax`, `executions.data` and `executions.pruning` stay. Those values do what they say and conflict with no other setting.
- A check other than a retired key that an unmigrated previous-major example trips fails the upgrade test.
