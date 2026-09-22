# Design principles for the n8n chart

This chart is the core n8n deployment for Kubernetes: the thing users install directly, that n8n's Terraform modules install, and the base other charts build on. These are the properties we hold every change against in review.

They exist because the chart has more than one consumer with conflicting needs. Enterprise customers bring wildly different tooling stacks, our own Terraform is opinionated by design, and n8n Cloud runs a mass-deployment model. Without a written line, the core becomes a grab bag of everyone's requirements.

The principles are the standing rules. The individual calls we make under them live one per file in `decisions/`, with the reasoning behind each.

## The principles

**The core deploys n8n and nothing else.**

Every resource the chart renders either runs an n8n process or configures one. If a resource would still make sense with n8n removed from the chart, it belongs in a layer above, not here.
*How we check it:* `helm template` renders only workloads, Services, ConfigMaps, Secrets and the primitives listed below, each owned by an n8n component.

**State is external and reached through a contract.**

Postgres, Redis and object storage are entities the chart connects to. The contract is a hostname plus an existing Secret with documented, configurable key names, so any operator-generated Secret (CloudNativePG, an RDS operator, Crossplane) works without a shim.
*How we check it:* `Chart.yaml` has no `dependencies:` block, and every datastore example uses `existingSecret`.

**Portable primitives with portable defaults.**

The chart ships every Kubernetes primitive n8n needs to run well (Ingress, HPA, PDB, NetworkPolicy, Services, ServiceAccount, PVC), and none of them assumes a vendor. No default annotations only one ingress controller reads, no default storage class, no default cloud IAM wiring. Vendor specifics arrive through passthroughs (`annotations`, `className`, `extraObjects`) and live in the examples.
*How we check it:* the default render is valid on kind, EKS, AKS and GKE with no values changes, and nothing in `templates/` names a specific controller or cloud.

**One place to set anything, and a defined winner.**

Every setting has exactly one home in values. Where a user override can meet a chart-managed setting, the precedence is documented; where two user inputs would set the same thing, the chart refuses to render rather than picking silently.
*How we check it:* the schema rejects unknown keys, and a unit test covers the duplicate-key refusal.

**Fail loudly, never silently.**

A value that doesn't do what it appears to do is a bug, not a documentation gap. Misconfigurations are caught at render time with a message that names the fix. S3 enabled but binary data on local disk, or multi-main without a licence, are the cases this principle exists to prevent.
*How we check it:* every `fail` in the validation helper has a unit test.

**Renders deterministically without a cluster.**

`helm template` and Argo CD produce the same output as `helm install`. No `lookup`, no generated secrets, no random values. Anything unique to an install (the encryption key, the task-runner token) is supplied by the user or read from an existing Secret, and the chart fails without it.
*How we check it:* two consecutive `helm template` runs diff clean.

**Every supported configuration is a file the chart tests.**

The `examples/` directory is the supported surface: one values file per topology and size, each installed and upgraded in CI on every change. If a configuration isn't an example, it isn't supported; if it's an example, it's tested.

**Upgrades are in place, across majors included.**

Resource names, labels and selectors are stable across versions, so `helm upgrade` rolls pods and does nothing else. A major may change values keys; when it does, retired keys fail with the replacement named, and CI proves the upgrade from the last minor of the previous major on every example.

**Versioned with n8n, not by n8n.**

`appVersion` tracks n8n; `version` tracks the chart. An n8n major requires a chart major and a maintenance branch for the old line; a chart major does not require an n8n major. Customers read the changelog, not the version number, to learn what changed.

**Consumable as a subchart without a fork.**

Everything a downstream layer needs (Cloud's umbrellas, our Terraform, a customer's own wrapper) is reachable through values. If a consumer has to patch a template, the core is missing a passthrough, and that's a chart bug.

## What the core expects the cluster to provide

These are cluster-level concerns, one per cluster and shared by every application on it. The chart connects to them and the examples show how; it doesn't install them.

- Datastores: Postgres, Redis or Valkey, object storage.
- An ingress controller, or a Gateway API implementation.
- A certificate issuer, such as cert-manager.
- Metrics collection, such as Prometheus. The chart can render a ServiceMonitor or PodMonitor when asked.

## The cost we accept

No generated encryption key means a bare `helm install` with no values fails. This is a usability trade-off: a key the chart generates is a key that regenerates under `helm template` and Argo CD, and a chart that silently mints the credential protecting every stored secret is a worse outcome than a clear error on first install.

To compensate, we develop generous examples and scripts (like `create-secrets.sh`) to make the correct path the short one.
