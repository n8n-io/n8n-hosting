# 0005. Security context is set per role

Date: 2026-10-09
PR: https://github.com/n8n-io/n8n-hosting/pull/236

## Context

The chart had one `securityContext` block for every pod. It set `fsGroup`, `runAsUser` and `runAsGroup` from values, and always added `runAsNonRoot: true` and the `RuntimeDefault` seccomp profile. The n8n containers and the task-runner sidecar got `allowPrivilegeEscalation: false` and dropped all capabilities, and none of that could be changed from values.

That is too coarse for some clusters. OpenShift's restricted SCC assigns the UID and GID itself and rejects a pod that pins them. n8n's task-runner hardening guide runs the runner as `nobody` (UID and GID 65532), not 1000. A read-only root filesystem suits some containers before others. The only escape was `securityContext.enabled: false`, which drops every pod default at once.

## Decision

Two maps hold the security context per role: `podSecurityContext.{main,worker,webhookProcessor}` and `containerSecurityContext.{main,worker,webhookProcessor,taskRunner}`. `taskRunner` covers the sidecar on both main and worker pods. Both render as plain Helm values, with no merge logic in the templates.

- **Containers.** The hardened defaults live in `values.yaml` under each role. Helm merges user values over them, so an override names only the fields it changes, and a `null` removes a default. This is how most multi-component charts set container context (Argo CD, Bitnami, GitLab, Temporal, Mimir).
- **Pods.** `securityContext` stays the chart-wide default, so existing values render the same objects. A `podSecurityContext.<role>` block, when set, replaces it for that role and renders as written. `values.yaml` cannot derive one value from another, so a merge over `securityContext` would need template logic. A replace is one rule users already know from Airflow's chart.

There is no chart-wide container key. It would need the same template merge, and DESIGN.md's "One place to set anything, and a defined winner" favours one home per field. A setting for several containers can be written once with a YAML anchor.

## Consequences

- A pod override must restate every field it wants. A block with only `runAsUser` drops `runAsNonRoot` and seccomp for that role. Clusters enforcing the `restricted` Pod Security Standard reject such a pod.
- Container defaults are visible in `values.yaml` and `helm show values`.
- A list such as `capabilities.drop` is replaced whole, not appended to.
- Pod and container work differently in 1.x because `securityContext` predates the per-role maps. Retiring `securityContext` in 2.0 and moving its defaults into `podSecurityContext.<role>` in `values.yaml` would make both work the same way.
- The role names follow the 1.x keys (`webhookProcessor`). A 2.0 rename of roles applies to these maps too.
