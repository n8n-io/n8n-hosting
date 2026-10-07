# 0005. Several mains render only with multi-main and a licence

Date: 2026-10-06
PR: https://github.com/n8n-io/n8n-hosting/pull/229

## Context

n8n mains coordinate only in multi-main mode, which is an Enterprise feature. The chart sets `N8N_MULTI_MAIN_SETUP_ENABLED` only when both `multiMain.enabled` and `license.enabled` are true. Without multi-main, every main acts as the leader: it runs schedules, activates triggers and does the leader housekeeping on its own. The chart still rendered several mains in three ways: `multiMain.enabled` with no licence, `replicaCount` above 1, and a main HPA that could scale past one pod.

## Decision

The render fails when `multiMain.enabled` is true and `license.enabled` is false. Without `multiMain.enabled`, it also fails when `replicaCount` is above 1, or when `hpa.main.enabled` is true and `hpa.main.maxReplicas` is above 1. This sits under "Fail loudly, never silently", which names multi-main without a licence.

These checks land on chart 1.x as a fix rather than waiting for 2.0, because every install they stop runs, or can scale to, uncoordinated mains.

## Consequences

- An install that matches any of these rules stops rendering on upgrade. The message names the values to set.
- `license.enabled: true` with no key in values is accepted, for a licence supplied through `extraEnvFrom` or activated in n8n.
- A main HPA with `maxReplicas: 1` still renders.
- The chart offers no switch to run several mains without multi-main. A user's own HPA in `extraObjects` can still do it, outside what the chart supports.
