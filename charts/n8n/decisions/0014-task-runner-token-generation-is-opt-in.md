# 0014. Generating the task-runner token is opt-in

Date: 2026-10-15
PR: https://github.com/n8n-io/n8n-hosting/pull/252

## Context

Task runners authenticate to the n8n task broker with a shared token. When no token was supplied, the chart made one: it used `lookup` to read the token from the Secret already in the cluster, and generated a random one with `randAlphaNum` when there was none.

That works when Helm can reach the cluster, as with `helm install`, `helm upgrade` and Flux. `lookup` returns nothing under `helm template`, and Argo CD renders that way. There every render generated a new token. Argo CD showed the Secret as out of sync on every sync, and a sidecar that restarted after a sync read a token the n8n container did not hold, so Code nodes failed to authenticate. The Secret also rendered with task runners disabled.

Requiring a token everywhere fixes this, but costs every install one more Secret, including a first install that only wants to try n8n.

## Decision

With task runners enabled, the user supplies the token in one of three ways:

- `taskRunners.authToken.existingSecret`, a Secret the user manages.
- `taskRunners.authToken.value`, from which the chart renders the Secret.
- `taskRunners.authToken.generate: true`, which keeps the `lookup` and `randAlphaNum` behaviour.

`generate` is off by default. Without any of the three, the render fails and the message names all of them. The chart renders the task-runner Secret only when task runners are enabled and no existing Secret is named.

This sits under "Renders deterministically without a cluster": the default render is the same under `helm template`, Argo CD and `helm install`. Generation is a convenience the user turns on, and `values.yaml` says it needs Helm to reach the cluster.

## Consequences

- An install with task runners enabled and no token fails on upgrade until it chooses a source. `generate: true` keeps the token it already has, because `lookup` reads it back.
- The `generate` path is not deterministic. Users who render without a cluster use `existingSecret` or `value`.
- The chart does not create secrets with a hook or a Job. Any other value unique to an install comes from the user or from a Secret they manage.
