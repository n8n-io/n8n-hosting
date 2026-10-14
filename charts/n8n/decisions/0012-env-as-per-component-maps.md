# 0012. Environment variables are per-component maps delivered with envFrom

Date: 2026-10-14
PR: https://github.com/n8n-io/n8n-hosting/pull/000

## Context

Chart 1.x built each container's environment as a list of `valueFrom` entries, one per variable, plus nine `extraEnv` lists for user variables. Lists do not merge across values files. When a list set the same variable as the chart, Kubernetes kept whichever entry came last, and server-side apply rejects duplicate names. Nothing per component covered settings such as a worker-only log level.

`secretRefs.env` also held `N8N_HOST`, `N8N_PORT` and `N8N_PROTOCOL` beside the encryption key. An `existingSecret` had to carry all four, although only the key is secret.

## Decision

Users set variables in `env.shared`, `env.main`, `env.worker`, `env.webhookProcessor` and `env.taskRunner`. These are flat maps of `NAME: value`. The component names match the chart's other per-component values. `shared` reaches the n8n processes but not the task-runner sidecar. The launcher reads none of n8n's settings and runs user code.

The chart renders one ConfigMap for shared variables and one per component. Each holds the variables the chart computes and the user's map. Containers load them with `envFrom`, shared first, so a component's value wins over the shared one. The explicit `env` list keeps only variables read from a Secret. Each entry names one key, so other keys in that Secret are never loaded. Each pod's `checksum/config` covers only the ConfigMaps it loads.

A user map that sets a variable the chart sets for that component fails the render. The message names the value that controls it. The check uses what the chart sets in the current configuration, not a fixed list. A variable the chart leaves alone, such as `AWS_ACCESS_KEY_ID` with S3 off, stays available. This follows *One place to set anything, and a defined winner*.

`chartEnvOverrides` replaces a variable the chart sets, for cases its value cannot express. It accepts only variables the chart sets in the current configuration, and not ones read from a Secret. The override replaces the value inside the chart's ConfigMap, so the container still gets one entry. `NOTES.txt` lists overrides in effect. User `envFrom` refs load after the chart's ConfigMaps and win over them, because the chart cannot see inside them. `config.extraEnvFrom` loads before the chart's ConfigMaps, so the chart's values win over it.

Map values may be strings, numbers or booleans. Whole numbers render without an exponent. Helm reads `1000000` as a float, and printing it directly gives `1e+06`.

`secretRefs.env` keeps `N8N_ENCRYPTION_KEY` and `N8N_ENCRYPTION_KEY_FILE`. The chart sets `N8N_PORT` from `service.port` on every n8n process. It does not set `N8N_HOST` or `N8N_PROTOCOL`. n8n reads them only to build a fallback URL when `N8N_WEBHOOK_URL` and `N8N_EDITOR_BASE_URL` are unset. Deriving the protocol from ingress TLS would contradict decision 0006.

`webhook.timeout` is removed. It rendered `N8N_WEBHOOK_TIMEOUT`, and n8n has never read that variable.

`queueMode.workerConcurrency` is empty by default, so workers get no `--concurrency` flag and n8n's default applies. n8n takes a worker's concurrency from `N8N_CONCURRENCY_PRODUCTION_LIMIT` when it is set, and ignores the flag. In queue mode, the render fails when both are set.

## Consequences

- Upgrading needs values changes. `secretRefs.env.N8N_HOST`, `N8N_PORT`, `N8N_PROTOCOL` and `webhook.timeout` fail the render with the replacement named. An `existingSecret` that still holds the three keys keeps working, because the chart no longer reads them.
- Installs that set both `queueMode.workerConcurrency` and `executions.concurrency.productionLimit` in queue mode must remove one. Their workers ran at `productionLimit`.
- Workers now receive `N8N_PORT`, like the other n8n processes.
- An `envFrom` ConfigMap or Secret can override any chart value, and the chart cannot check it. Changing it does not restart pods.
- The `extraEnv` lists remain until a later change removes them. A variable set in both a list and a map fails the render.
