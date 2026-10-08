# 0005. Per-role securityContext merges over the chart defaults

Date: 2026-10-07
PR: https://github.com/n8n-io/n8n-hosting/pull/236

## Context

The chart had one `securityContext` block for every pod. It set `fsGroup`, `runAsUser` and `runAsGroup` from values, and always added `runAsNonRoot: true` and the `RuntimeDefault` seccomp profile. Every container got `allowPrivilegeEscalation: false` and dropped all capabilities, and none of that could be changed from values.

That is too coarse for some clusters. OpenShift's restricted SCC assigns the UID and GID itself and rejects a pod that pins them. n8n's task-runner hardening guide runs the runner as `nobody` (UID and GID 65532), not 1000. A read-only root filesystem suits some containers before others. The only escape was `securityContext.enabled: false`, which also dropped `runAsNonRoot` and seccomp.

## Decision

Two new maps hold overrides per role: `podSecurityContext.{main,worker,webhookProcessor}` and `containerSecurityContext.{main,worker,webhookProcessor,taskRunner}`. `taskRunner` covers the sidecar on both main and worker pods.

Each role block deep-merges over the defaults: the pod block over `securityContext`, the container block over the hardened container default. A field set to `null` is removed. `securityContext` keeps its keys and defaults, so existing values render the same objects. `securityContext.enabled: false` drops the chart's pod defaults, but a role block still applies, because the chart does not ignore a value the user set.

There is no chart-wide container key. Most multi-component charts (Argo CD, Bitnami, GitLab, Temporal, Mimir) set the container context per component only. Airflow has a chart-wide container key, but a component block replaces it whole, which is a precedence rule users have to learn. This sits under "One place to set anything, and a defined winner": each container field has one home, and the role block always wins.

## Consequences

- OpenShift installs can remove the pinned IDs and keep `runAsNonRoot` and seccomp.
- An override names only the fields it changes. Setting `runAsUser` for the runner keeps the dropped capabilities.
- A list such as `capabilities.drop` is replaced whole, not appended to.
- A setting that should apply to every container, such as a read-only root filesystem, has to be set on each role, or added later as its own value.
- The role names follow the 1.x keys (`webhookProcessor`). A 2.0 rename of roles applies to these maps too.
