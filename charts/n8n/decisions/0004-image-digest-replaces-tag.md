# 0004. An image digest replaces the tag

Date: 2026-10-07
PR: https://github.com/n8n-io/n8n-hosting/pull/000

## Context

Some installs must pull every image by digest. Marketplace offers such as Azure's Kubernetes app require it, and security reviews often ask for it, because a tag can be moved to a different image after it was approved.

The chart builds two image references: the n8n image, and the task runner sidecar image. Both resolved by tag only. A digest can be written in two ways:

- `repository@sha256:...`, where the digest alone decides the image.
- `repository:tag@sha256:...`, where the tag is kept for readability and the container runtime ignores it.

## Decision

`image.digest` and `taskRunners.image.digest`, when set, render `repository@digest` and the tag is not rendered. This sits under "Fail loudly, never silently": in the combined form the tag looks meaningful but does nothing, so a reader can believe a pod runs a version it does not.

The two digests are independent. The runner is a separate image, so `image.digest` never applies to it, and setting one does not pin the other. The schema accepts only an empty string or `sha256:` followed by 64 hex characters. Registries that serve n8n images use sha256, so the schema rejects other algorithms.

The chart does not resolve digests. The weekly n8n bump moves `appVersion` only, and a digest a user sets stays until they change it.

## Consequences

- A digest-pinned install shows no version in the image reference. The `app.kubernetes.io/version` label still shows the chart's `appVersion`, which may differ from the pinned image.
- Upgrading a pinned install means updating the digest. Changing `image.tag` alone has no effect while a digest is set.
- A user who pins the n8n image and runs task runners must also pin the runner, or the runner still pulls by tag.
