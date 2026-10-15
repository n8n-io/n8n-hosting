# 0014. Task runners are on by default

Date: 2026-10-15
PR: https://github.com/n8n-io/n8n-hosting/pull/252

## Context

n8n runs user code from Code nodes either inside the n8n process (internal mode) or in a separate runner (external mode). The chart supported external mode as an opt-in sidecar, so a default install ran internal mode.

n8n 3.0 deprecates internal mode and logs a warning at startup whenever `N8N_RUNNERS_MODE` is unset. Its removal is planned. External runners are n8n's recommendation for production. Every install on the default would have to move, and a default install that warns on every start looks unmaintained.

## Decision

`taskRunners.enabled` defaults to `true`, in queue mode and in standalone. The sidecar runs on worker pods in queue mode and on the main pod in standalone, as it already did when enabled. Its memory request is `128Mi`, down from `256Mi`, and its limit stays `512Mi`. The scheduling footprint stays small, and the runner can still use more memory when a task needs it. The liveness probe on the launcher restarts a sidecar that stops responding.

This sits under "Versioned with n8n, not by n8n": chart 2.0 ships n8n 3.0, so its default follows what n8n 3.0 recommends. Chart 2.0 is a major version that users already upgrade with care, so the default changes here rather than in a later minor.

## Consequences

- Each worker pod, or the main pod in standalone, has a second container and requests 100m CPU and 128Mi more.
- A default install needs a task-runner token source, as [0019](0019-task-runner-token-generation-is-opt-in.md) describes. Every example supplies one.
- `taskRunners.enabled: false` keeps internal mode until n8n removes it.
