# 0004. The main PodDisruptionBudget renders only with a second main pod

Date: 2026-10-06
PR: https://github.com/n8n-io/n8n-hosting/pull/228

## Context

The chart ships a PodDisruptionBudget for main pods with `minAvailable: 1`. `pdb.enabled` defaults to true and `replicaCount` defaults to 1. With one main pod, a budget of `minAvailable: 1` allows no voluntary evictions at all. `kubectl drain`, cluster autoscaler scale-down and managed node upgrades wait on it until someone deletes the budget by hand. Standalone installs default to one main pod, so they start in this state.

A PDB protects availability only when another pod keeps serving while one is evicted. With a single pod, the eviction causes the outage whether or not a budget exists. The budget only decides whether the node can be drained.

## Decision

The main PodDisruptionBudget renders when `pdb.enabled` is true and main can run more than one pod. That means the effective replica count (`multiMain.replicas` under multi-main, otherwise `replicaCount`) is above one, or `hpa.main` is enabled with `minReplicas` above one. `pdb.enabled` stays the master switch, and `false` never renders a budget.

This sits under "Portable primitives with portable defaults": the default render has to work with ordinary cluster operations on any provider, and node drains are one of them. "Fail loudly, never silently" was weighed. Failing the render on `pdb.enabled: true` with one replica would break every default install. `pdb.enabled` is documented as covering main when main has more than one pod.

## Consequences

- Single-replica installs, including every default and standalone install, no longer carry a budget, and their nodes drain normally. On upgrade, Helm deletes the existing PDB.
- Installs that run more than one main pod render exactly as before.
- The budget is decided at render time, not from the live pod count. With `hpa.main.minReplicas: 1`, the budget follows `replicaCount`. An HPA that scales main up from one pod gets no budget. An HPA that scales main down to one pod keeps a budget that blocks drains while it sits at one. Set `hpa.main.minReplicas` to 2 or more to avoid both.
- The gate assumes `pdb.minAvailable` is lower than the replica count. A `minAvailable` equal to the replica count still blocks drains.
- Workers and webhook processors still have no PDB. Adding one is separate work.
