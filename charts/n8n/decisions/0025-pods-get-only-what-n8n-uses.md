# 0025. Pods get only what n8n uses, and main recreates on single-node storage

Date: 2026-10-20
PR: https://github.com/n8n-io/n8n-hosting/pull/266

## Context

Chart 1.x shipped three defaults that n8n does not need:

- Kubernetes adds `<SERVICE>_SERVICE_HOST`, `<SERVICE>_PORT` and related variables for every Service in the namespace to every pod. n8n reads none of them, so each pod's environment grows with the namespace and carries the address of every Service in it.
- The chart created a Role that reads ConfigMaps and Secrets, and Kubernetes mounted the ServiceAccount token into each pod. n8n never calls the Kubernetes API, and it runs code its users write, so the token gives that code access it has no use for.
- The main Deployment used a rolling update, which starts the new pod before the old one stops. A `ReadWriteOnce` volume cannot attach to the new pod on another node while the old pod holds it, so the rollout waits until someone deletes the old pod. The values file told users to set `Recreate` by hand.

## Decision

The chart sets `enableServiceLinks: false` on every n8n pod, and `rbac.create` and `serviceAccount.automountServiceAccountToken` default to `false`. Each stays a value, so an install that needs one can turn it back on. This sits under DESIGN.md's "Portable primitives with portable defaults": the default render grants nothing n8n does not use.

When `strategy` is empty, `persistence.enabled` is true and every entry in `persistence.accessModes` is `ReadWriteOnce` or `ReadWriteOncePod`, the main Deployment uses `Recreate`. A `strategy` the user sets always wins. The chart reads the access modes from values rather than from the cluster, so it still renders without one. With `existingClaim`, the user describes their claim in `persistence.accessModes`. Other storage, and installs without persistence, keep the Kubernetes default.

The chart renders `rollingUpdate: null` with `Recreate`, its own or a user's that sets no `rollingUpdate`. Kubernetes filled in `rollingUpdate` on every 1.x Deployment and rejects it alongside `Recreate`, and the null removes it when Helm applies the change on the client.

## Consequences

- n8n's pods carry only the variables the chart and the user set. A container added with `extraContainers` or `extraInitContainers` that reads a Service link needs `enableServiceLinks: true`.
- Upgrading a single-node volume from 1.x has a short outage on each upgrade instead of a rollout that can stall. The volume moves to the new pod's node if the storage allows it, or the pod goes back to the node that holds a local volume.
- Server-side apply does not remove a field it did not set, so the null does not help a 1.x release that Helm 4 installed. Its first upgrade fails with an error that names `rollingUpdate`, and runs once with `--server-side=false`. The render cannot see how a release was applied, so the chart cannot catch this. [UPGRADING.md](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/UPGRADING.md#changed-defaults) names the error and the flag.
- The upgrade removes the 1.x Role and RoleBinding.
