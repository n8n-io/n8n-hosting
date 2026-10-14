# 0010. Chart 1.x moves to its maintenance branch before n8n 3.0 ships

Date: 2026-10-14
PR: https://github.com/n8n-io/n8n-hosting/pull/000

## Context

[0001](0001-chart-versioning.md) gives each n8n major its own maintenance branch. Chart 1.x is the line for n8n 2.x, so it needs a branch once n8n 3.0 ships with chart 2.0.

Chart 2.0 changes values keys and defaults. While `main` is the 1.x line, every merge to it can go out in the next weekly 1.x release, so that work cannot land there. A separate 2.0 branch merged back into `main` on release would need regular merges between two long-lived branches, which a repository that squashes every PR cannot record.

## Decision

`release/n8n-2.x` is cut from `main` at the 1.16.0 release, ahead of n8n 3.0. From then on:

- `main` is the chart 2.0 line. It releases `2.0.0-rc.1`, `2.0.0-rc.2` and so on until 2.0.0, which ships with n8n 3.0.
- `release/n8n-2.x` is the chart 1.x line. It continues from 1.16.0 and stays on n8n 2.x.
- Both publish to `oci://ghcr.io/n8n-io/n8n-helm-chart`, at versions that never overlap. This follows "Versioned with n8n, not by n8n".
- Changes land on `main` first. A change that applies to 1.x reaches the maintenance branch as a backport, opened from a `backport release/n8n-2.x` label. A breaking change is never backported.
- The weekly n8n bump runs once for each line. Each line stays within the n8n major its `appVersion` is on.

Nothing merges between the branches, so chart 2.0.0 is released from `main` as it stands.

## Consequences

- `helm install` and `helm upgrade` keep resolving to the latest 1.x release. Helm skips release candidates unless you pass `--devel` or name the exact version.
- To try chart 2.0 early, install a release candidate by its exact version, for example `--version 2.0.0-rc.1`. A release candidate can still change values keys before 2.0.0.
- Chart 1.x keeps getting the weekly n8n 2.x bump and fixes for as long as n8n supports 2.x.
- Signatures name the branch that built the release. The verification command in the README accepts `main` and any `release/n8n-<major>.x` branch.
