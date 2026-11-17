# 0027. Worker probes run a command or the health endpoint

Date: 2026-10-27
PR: https://github.com/n8n-io/n8n-hosting/pull/271
Supersedes: [0013](0013-worker-probes-use-the-queue-health-endpoint.md)

## Context

Decision 0013 moved worker probes onto n8n's queue health endpoint. It shipped in chart 1.x as a fix, so every 1.x values file had to keep rendering. It kept three things that do not do what they appear to do:

- With the health endpoint off and no `command`, the chart probed with `pgrep -f 'n8n worker'`. That check always passes, because the probe's own shell command line contains the string. Values files copied whole from chart 1.16 or earlier carry this shape: `redis.healthCheck.enabled: false`, with `type: exec` and the `pgrep` command on both probes.
- `type: httpGet` with a `command` ignored the command without a word.
- `type: exec` with no `command` ran the process check.

Chart 2.0 can remove them, because a major can ask users to change their values.

## Decision

A worker liveness or readiness probe is HTTP against the health endpoint, or `exec` running the `command` the user sets. The `command` alone decides which: set means exec, empty means HTTP. `probes.worker.liveness.type` and `probes.worker.readiness.type` are retired and listed in `n8n.retiredKeys` (decision 0020). With one input deciding the probe, a values file cannot ask for HTTP and set a command the probe would ignore. The chart has no process check of its own.

With `redis.healthCheck.enabled: false`, an enabled liveness or readiness probe with no `command` has nothing to check, and the render fails. The message names the three fixes: turn the health endpoint back on, set a `command`, or disable that probe. This follows "Fail loudly, never silently".

The chart does not inspect a `command`. What the user's command checks is theirs to decide.

The rest of 0013 stands: the health endpoint is on by default, the probe paths, and the startup probe, which renders only when the health endpoint is on.

## Consequences

- With default values, nothing changes. Workers keep their HTTP probes, and the pods do not roll.
- A values file that sets either `type` key fails the render until the key is removed. A values file copied whole from chart 1.16 or earlier sets both.
- A user who keeps the 1.x `pgrep` command keeps a probe that always passes. `UPGRADING.md` tells them to remove it.
- Chart 1.x keeps `type` and the process check, as 0013 describes.
