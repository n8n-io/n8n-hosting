# 0002. The install test runs examples on kind against plain Postgres and Redis

Date: 2026-09-24
PR: https://github.com/n8n-io/n8n-hosting/pull/000

## Context

The chart's install test installed the chart defaults, not an example, and took Postgres and Redis from the Bitnami chart repository. Bitnami moved its versioned images to `bitnamilegacy` in August 2025, and its chart repository is on the same path. Once that repository goes, a test that depends on it stops running.

The Helm E2E suite in `n8n-io/n8n` also installs this chart. It builds n8n from a branch, installs the chart from `main` on k3s with `examples/minimal.yaml` or `examples/standalone.yaml`, and runs part of n8n's Playwright suite. It reaches n8n by patching the `n8n-main` Service and finds pods by the `app.kubernetes.io/name` label. It lives in another repository, runs on another team's runners and only runs when its own files change.

## Decision

The two test suites have different jobs. n8n's suite tests an n8n build against the chart. This repository tests a chart change against the pinned `appVersion`.

The install test runs on kind. kind runs the standard Kubernetes control plane without bundled extras, can run several nodes with labels, and can pin a Kubernetes version per node image. k3s would start a little faster, but it adds Traefik, ServiceLB and kine by default, and using it would not let us share any code with n8n's suite.

Each install leg uses an example file as a customer would, overriding only the placeholder hosts and Secret name. The legs are `minimal.yaml`, `standalone.yaml` and `task-runners.yaml`. Every example still renders on every pull request.

Postgres and Redis come from plain Deployment and Service manifests in `ci/fixtures/`, using the official `postgres` and `redis` images. This follows "State is external and reached through a contract": the chart needs a hostname and an existing Secret, so test scaffolding needs nothing more. The fixtures are test scaffolding, not a recommendation for running either datastore.

The values and names n8n's suite relies on are covered by `tests/n8n-harness-contract_test.yaml`. This follows "Upgrades are in place, across majors included", which already requires stable resource names and labels.

## Consequences

- The install test depends on no third-party chart repository.
- An example that stops installing fails CI on the pull request that broke it, for the examples with an install leg.
- A chart change that renames `n8n-main`, changes the name label, or moves `minimal.yaml` or `standalone.yaml` fails the contract test before it can break n8n's suite.
- Examples that need a licence, KEDA, an ingress controller or labelled nodes are rendered but not installed.
- The fixture image versions are pinned here and move by hand.
