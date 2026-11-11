# 0031. Chart 2.0.0 ends the release candidates on main

Date: 2026-11-10
PR: https://github.com/n8n-io/n8n-hosting/pull/290

## Context

[0010](0010-maintenance-branch-ahead-of-the-n8n-major.md) has `main` release `2.0.0-rc.1`, `2.0.0-rc.2` and so on until n8n 3.0 ships. Two settings make those versions release candidates. In `release-please-config.json`, `prerelease: true` and `prerelease-type: rc` make release-please propose the next `-rc.N`. In `Chart.yaml`, the `artifacthub.io/prerelease` annotation stops Artifact Hub from listing a release candidate as the chart's latest version.

The 2.0.0 release has to turn both off. release-please must then propose exactly `2.0.0`, whatever commit types have merged since the last release candidate.

## Decision

This sits under "Versioned with n8n, not by n8n": chart 2.0.0 is the first full release of the line for n8n 3.0.

`main` keeps `versioning: prerelease` and drops `prerelease` and `prerelease-type`. With `prerelease` off, this strategy works out the next release candidate and then drops the suffix, so every commit type takes `2.0.0-rc.N` to `2.0.0`. From a version with no suffix, it bumps major, minor and patch in the same way as release-please's default strategy.

The `default` strategy does not reach `2.0.0`. It keeps the suffix when it bumps, so a breaking commit after `2.0.0-rc.1` gives `3.0.0-rc.1`, and a feature gives `2.1.0-rc.1`.

`Chart.yaml` drops the `artifacthub.io/prerelease` annotation in the same change, so that Artifact Hub lists 2.0.0 as a full release.

The change merges after the commit that moves `appVersion` to n8n 3.0. Otherwise the release PR would offer 2.0.0 on n8n 2.x.

## Consequences

- The release PR that follows this change proposes `2.0.0`, and its GitHub release is not marked as a pre-release.
- `helm install` and `helm upgrade` with no `--version` now resolve to chart 2.x. Installs that stay on n8n 2.x pin a 1.x version.
- A later major can run release candidates on `main` in the same way. Set `prerelease: true` and `prerelease-type: rc`, and add the annotation back. Remove all three in the change that releases the major.
