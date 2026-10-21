# 0016. The values schema rejects unknown keys

Date: 2026-10-21
PR: https://github.com/n8n-io/n8n-hosting/pull/TBD

## Context

Helm accepts any key in a values file, even one that no template reads. A typo such as `databse.host` or `queueMode.workerReplicas`, or a key copied from another n8n chart, renders exactly as if it were absent. The install runs on the chart defaults, and nothing says why.

The retired-keys guard ([0020](0020-retired-values-keys-fail-the-render.md)) covers keys the chart has removed, and names the replacement for each. It cannot cover a key that was never part of the chart, or a removed key nobody added to the list.

JSON Schema can close an object with `additionalProperties: false`, so Helm rejects any key the schema does not declare. Few charts do this at the root. Traefik, cert-manager and the community-charts n8n chart do, and each one broke umbrella installs at first: Helm passes a parent's `global` block into every subchart, and a parent's dependency condition adds `enabled` to the subchart's values. Most other charts check types only, or ship no schema.

## Decision

`values.schema.json` closes the root and every block whose keys the chart defines. Helm then fails the install or upgrade before rendering, and names each unknown key and where it sits. This sits under DESIGN.md's "Fail loudly, never silently" and "One place to set anything, and a defined winner".

These stay open, because their keys belong to Kubernetes or to the user, and the chart passes them through as written:

- `annotations` and `labels` blocks, including `commonLabels`, `commonAnnotations`, `podLabels` and `podAnnotations`
- `nodeSelector`, `tolerations` and `affinity`, at the root and under `nodePlacement`
- `resources` for each component and for the task runner
- `strategy` and `dnsConfig`
- `extraObjects`, `extraContainers`, `extraInitContainers`, `extraVolumes` and `extraVolumeMounts`
- `secretRefs.env`, and the `env`, `chartEnvOverrides` and `envFrom` maps, whose variable names are the user's
- `metadata` in KEDA triggers

The root declares `global` as an open object and `enabled` as accepting only `true`, so the chart works as a subchart. The chart reads neither. When a parent sets `enabled: false`, Helm drops the subchart before the schema runs. So the only `false` the schema sees comes from installing the chart directly, where it would do nothing.

Retired keys stay declared and accept any value, so the guard's message naming the replacement is what a user sees for them.

Closing a block does not add new constraints on the values inside it. A value accepts an integer or a string wherever Kubernetes does, and `enum` is used only where `values.yaml` already lists the options.

## Consequences

- An upgrade from 1.x fails on any key 2.0 does not declare. Users render their values against the new chart first, as `UPGRADING.md` already asks, and remove each key the error names.
- Users who keep their own top-level keys, for YAML anchors or for values that `extraObjects` reads through `tpl`, move them under `global`.
- `--skip-schema-validation` in Helm 3.16 and later, or `disableSchemaValidation` in Flux, skips the schema. `n8n.validate` still runs. Neither option helps when the chart is a subchart.
- Every value a template reads must be declared in the schema, including optional values that `values.yaml` only documents in a comment. Otherwise a user who sets it gets a rejected install.
- Rejecting a key that 2.0 accepts is a breaking change, so a block can only be closed further in a major.
