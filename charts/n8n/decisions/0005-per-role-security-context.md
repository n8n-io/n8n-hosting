# 0005. Security context is shared, with per-role overrides

Date: 2026-10-15
PR: https://github.com/n8n-io/n8n-hosting/pull/236

## Context

Chart 1.x had one `securityContext` block for every pod. It set `fsGroup`, `runAsUser` and `runAsGroup` from values, and always added `runAsNonRoot: true` and the `RuntimeDefault` seccomp profile. The n8n containers and the task-runner sidecar got `allowPrivilegeEscalation: false` and dropped all capabilities, and none of that could be changed from values.

That is too coarse for some clusters. OpenShift's restricted SCC assigns the UID and GID itself and rejects a pod that pins them. n8n's task-runner hardening guide runs the runner as `nobody` (UID and GID 65532), not 1000. A read-only root filesystem suits some containers before others. The only escape was `securityContext.enabled: false`, which drops every pod default at once.

## Decision

Two maps hold the security context: `podSecurityContext` with `shared`, `main`, `worker` and `webhookProcessor`, and `containerSecurityContext` with `shared`, `main`, `worker`, `webhookProcessor` and `taskRunner`. `taskRunner` covers the sidecar on both main and worker pods.

The hardened defaults live in `values.yaml` under `shared`, and the role blocks default to empty. The chart merges each role block over `shared` field by field, and the role wins. Nested maps merge, a list replaces the inherited list whole, and a `null` removes a field. This is the same rule as `env.shared` and the per-component env maps, so users learn one rule for both. It sits under DESIGN.md's "One place to set anything, and a defined winner": each layer has one home, and the role always wins.

The chart writes the merge out in `n8n.mergeOver` instead of using Sprig's `mergeOverwrite`. Some Sprig versions skip `false` and `0` when overwriting, and a role must be able to set `runAsNonRoot: false` or `runAsUser: 0`.

`values.schema.json` types each block with the Kubernetes fields it accepts, so a misspelt field fails the render. Every field also accepts `null`.

## Consequences

- The defaults are visible in `values.yaml` and `helm show values`.
- A setting for every pod or container is one line in `shared`. A setting for one role overrides `shared` for that role only.
- On OpenShift, setting `fsGroup`, `runAsUser` and `runAsGroup` to `null` in `podSecurityContext.shared` keeps `runAsNonRoot` and seccomp, so the pods still meet the `restricted` Pod Security Standard.
- Helm drops a `null` on a key that has a default, so a role set to `null` keeps `shared`. To drop every default, set `shared` to `null`.
- The schema is closed, so a Kubernetes field the chart does not list fails the render until the chart adds it. Windows fields are not listed, because n8n ships Linux images only.
- `securityContext` is retired in 2.0. A values file that sets it fails the render and names `podSecurityContext.shared`. `securityContext.enabled: false` becomes `podSecurityContext.shared: null`.
- A 1.x `podSecurityContext.<role>` block replaced the defaults, and in 2.0 it merges over `shared`. A block that left out the pinned IDs, as on OpenShift, must set them to `null`. The render cannot detect this, so `UPGRADING.md` calls it out.
- The role names follow the 1.x keys (`webhookProcessor`). A 2.0 rename of roles applies to these maps too.
