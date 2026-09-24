# 0002. The install test runs examples on kind against plain Postgres and Redis

Date: 2026-09-24
PR: https://github.com/n8n-io/n8n-hosting/pull/000

## Context

The chart's install test installed the chart defaults, not an example. It took Postgres and Redis from the Bitnami chart repository. Bitnami moved its versioned images to `bitnamilegacy` in August 2025 and is expected to withdraw the chart repository too. A test that depends on that repository would then stop running.

The Helm E2E suite in `n8n-io/n8n` also installs this chart. It installs the chart from `main` on k3s with `examples/minimal.yaml` or `examples/standalone.yaml`, then runs part of n8n's Playwright suite.

## Decision

More comprehensive end-to-end tests will be developed in n8n's own test suite or in another location. Those tests check an n8n build against the chart. The install test here checks chart changes against the pinned `appVersion`. Its job is good coverage of chart changes, so it does not need a more complex install.

The install test runs on kind, which runs the standard Kubernetes control plane without bundled extras and can pin a Kubernetes version per node image. k3s starts a little faster, but it bundles Traefik, ServiceLB and kine, and moving to it would not give us any code to share with n8n's suite.

Each install leg installs an example file. Only the placeholder hosts, the Secret name and the worker count are overridden. Postgres and Redis come from plain manifests in `ci/fixtures/` on the official `postgres` and `redis` images. This follows "State is external and reached through a contract": the chart needs a hostname and an existing Secret, and nothing more. The fixtures are test scaffolding, not a recommendation for running either datastore.

## Consequences

The install test depends on no third-party chart repository, and a broken `minimal.yaml`, `standalone.yaml` or `task-runners.yaml` fails CI on the pull request that broke it. The other examples need a licence, KEDA, an ingress controller or labelled nodes, so CI renders them but does not install them. The fixture image versions in `ci/fixtures/` are pinned and move by hand.
