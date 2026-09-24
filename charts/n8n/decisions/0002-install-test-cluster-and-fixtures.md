# 0002. The install test runs examples on kind against plain Postgres and Redis

Date: 2026-09-24
PR: https://github.com/n8n-io/n8n-hosting/pull/211

## Context

The chart's install test installed the chart defaults, not an example. It took Postgres and Redis from the Bitnami chart repository. Bitnami moved its versioned images to `bitnamilegacy` in August 2025 and is expected to withdraw the chart repository too. A test that depends on that repository would then stop running.

The Helm E2E suite in `n8n-io/n8n` also installs this chart. It installs the chart from `main` on k3s with `examples/minimal.yaml` or `examples/standalone.yaml`, then runs part of n8n's Playwright suite.

## Decision

Fuller end-to-end tests against an n8n build belong in n8n's own test suite or elsewhere. The install test here checks chart changes against the pinned `appVersion`. Its job is good coverage of chart changes, so it does not need a more complex install.

The install test runs on kind, which runs the standard Kubernetes control plane without bundled extras and can pin a Kubernetes version per node image. k3s starts a little faster, but it bundles Traefik, ServiceLB and kine, and moving to it would not give us any code to share with n8n's suite.

Each install leg installs an example file with an overlay from `ci/install/`, which replaces the example's placeholders and scales it down to fit a hosted runner. An example gets a leg by having an overlay. Postgres and Redis come from plain manifests in `ci/fixtures/` on the official `postgres` and `redis` images. This follows "State is external and reached through a contract": the chart needs a hostname and an existing Secret, and nothing more. The fixtures are test scaffolding, not a recommendation for running either datastore.

## Consequences

The install test depends on no third-party chart repository. A render break in any example fails `template-validation` on the pull request that caused it. An install break in `minimal.yaml`, `standalone.yaml` or `task-runners.yaml` fails `install-test` on labelled, bump and release pull requests. The other examples are rendered but not installed until they have an overlay. Most of them need a licence, S3, KEDA, an ingress controller or labelled nodes first. The fixture image versions in `ci/fixtures/` are pinned and move by hand.
