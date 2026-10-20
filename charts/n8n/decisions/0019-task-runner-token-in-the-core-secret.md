# 0019. The task-runner token lives in the core Secret

Date: 2026-10-20
PR: https://github.com/n8n-io/n8n-hosting/pull/252

## Context

Task runners authenticate to the n8n task broker with a shared token. When no token was supplied, the chart made one: it used `lookup` to read the token from the Secret already in the cluster, and generated a random one with `randAlphaNum` when there was none.

`lookup` returns nothing under `helm template`, and Argo CD renders that way. There every render generated a new token. Argo CD showed the Secret as out of sync on every sync, and a sidecar that restarted after a sync read a token the n8n container did not hold, so Code nodes failed to authenticate. The Secret also rendered with task runners disabled.

With task runners on by default ([0014](0014-task-runners-on-by-default.md)), every install needs a token. Every install already supplies one Secret value, the encryption key, either in a Secret the user manages or in values.

## Decision

The chart generates no secrets. The token is read from the core Secret under the key `N8N_RUNNERS_AUTH_TOKEN`:

- With `secretRefs.existingSecret`, from that Secret.
- Otherwise from the chart's Secret, which renders it from `secretRefs.env.N8N_RUNNERS_AUTH_TOKEN`, next to the encryption key.

`taskRunners.authToken.existingSecret` and `existingSecretKey` read it from a different Secret instead. `taskRunners.authToken.value` retires in favour of `secretRefs.env.N8N_RUNNERS_AUTH_TOKEN`.

This sits under "Renders deterministically without a cluster" and "One place to set anything, and a defined winner": the render is the same everywhere, and the secrets an install supplies live in one place.

## Consequences

- When the chart renders the core Secret, the render fails without a token, and the message shows how to create one.
- With `secretRefs.existingSecret`, the chart cannot see whether the key exists. A missing key stops the pods with an error that names it, as a missing encryption key does.
- Upgrading means adding one key to the core Secret. A new token works at once, because the runner and the broker share a pod and every pod restarts on upgrade.
- An opt-in that generates the token can be added later without breaking installs. Generating the encryption key is a separate question, because losing it makes every stored credential unreadable.
