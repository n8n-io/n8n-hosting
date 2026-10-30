# 0001. Chart versions are independent of n8n versions

Date: 2026-09-04
PR: https://github.com/n8n-io/n8n-hosting/pull/195

## Context

The chart used to ship `image.tag: "stable"` and `appVersion: "stable"`, which is convenient to maintain and causes some issues:

- `pullPolicy` is `IfNotPresent`, so kubelet only pulls an image that isn't already on the node. A node that cached `stable` weeks ago keeps running it while freshly scaled nodes pull the current one, so a cluster drifts onto mixed n8n versions as nodes cycle.
- The rendered pod spec is identical across chart upgrades, because the tag string never changes. Kubernetes creates no new ReplicaSet, so `helm upgrade` and `helm rollback` don't restart anything.
- Every resource carried `app.kubernetes.io/version: "stable"`, so inventory and observability tooling had nothing useful to report.
- Marketplace container offers for Kubernetes applications require image digests rather than tags, which a floating tag can't provide.

Pinning `appVersion` then raises the question of what the chart's own version means, because chart releases are immutable and so every `appVersion` change has to bump the chart version too.

## Decision

`appVersion` is the n8n version this chart release was built and tested against, and it always names a concrete release. `image.tag` defaults to it and remains overridable.

The chart's `version` is independent of `appVersion` and tracks the chart's own interface: values keys, defaults, and the minimum Kubernetes version. This is standard practice among mature charts, where GitLab, Temporal, Airflow, Camunda and Windmill all run chart majors unrelated to the application's.

`appVersion` moves on a schedule rather than on every n8n release. Each Wednesday, the day after n8n releases, `.github/workflows/bump-n8n-version.yml` resolves what n8n's `stable` release points at and, if it has moved, opens a PR updating `appVersion` and every other pinned artefact in the repository in the same change, so the repository only ever points at one n8n version. release-please then works out the chart version from the commits since the last release, writes the changelog and publishes to `oci://ghcr.io/n8n-io/n8n-helm-chart`. That weekly release also sweeps up whatever chart work merged during the week.

Each n8n major gets its own maintenance branch, supported in line with n8n's end-of-life policy. Every branch publishes to the same OCI repository at different chart versions, and the weekly job never crosses an n8n major on its own.

## Consequences

- `helm upgrade` and `helm rollback` do what they say, because the pod spec changes when the version does.
- `app.kubernetes.io/version` carries a real n8n version for whatever reads it.
- The chart can be pinned by digest, which is what marketplace packaging needs.
- Chart version and n8n version are not comparable. Read the changelog rather than the version number to learn what changed in a release.
- The chart version moves most weeks even when no template changed, because an `appVersion` bump is a chart release. One predictable artefact a week is the trade made here, rather than a release per merge.
- Anyone running a different n8n version sets `image.tag` and takes on the compatibility question themselves, since the chart is only tested against its own `appVersion`.
