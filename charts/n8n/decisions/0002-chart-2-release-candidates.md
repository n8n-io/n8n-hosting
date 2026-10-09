# 0002. Chart 2.0 is built on its own branch and ships release candidates

Date: 2026-09-23
PR: https://github.com/n8n-io/n8n-hosting/pull/208

## Context

Chart 2.0 changes values keys and defaults. Every merge to `main` can go out in the next weekly 1.x release, so the breaking work cannot land there. It still needs CI, and people need a way to try it before it ships.

## Decision

Chart 2.0 is built on the `chart-v2` branch. release-please runs on that branch with its own config and manifest. Each release from it is a pre-release, `2.0.0-rc.1`, `2.0.0-rc.2` and so on, and goes to the same `oci://ghcr.io/n8n-io/n8n-helm-chart` repository as the 1.x releases. This follows "Versioned with n8n, not by n8n": each line has its own version sequence in one repository.

`main` is merged into `chart-v2` regularly, so each release candidate includes the 1.x fixes. When 2.0.0 is released, `chart-v2` merges into `main` and the branch is retired. The 1.x line then continues on a maintenance branch of its own.

## Consequences

- Helm skips pre-release versions unless you pass `--devel` or name the exact version. `helm install` and `helm upgrade` keep resolving to the latest 1.x release.
- To try 2.0 early, install a release candidate by its exact version, for example `--version 2.0.0-rc.1`.
- GitHub marks each release candidate as a pre-release, so it never shows as the latest release.
- A release candidate can change values keys again before 2.0.0. Treat it as a test build, not a supported release.
