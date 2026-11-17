# 0007. Every example installs in CI, with the add-ons it expects

Date: 2026-09-25
PR: https://github.com/n8n-io/n8n-hosting/pull/215

## Context

Decision 0006 installed the three examples that need only Postgres and Redis. The rest expect things the chart does not deploy and a bare kind cluster does not have: KEDA, an ingress controller, a certificate issuer, S3, nodes in named pools, or an enterprise licence. The examples are the supported way to run the chart, so an example that CI only renders can stop installing without anyone noticing.

## Decision

Every example has an install leg. An example that expects something from the cluster gets it from a pre-install hook, `ci/install/<example>.pre.sh`. A post-install hook, `ci/install/<example>.post.sh`, checks that the example works with it. A leg that needs more than one node brings a kind config in `ci/kind/`. This follows the chart's list of what the core expects the cluster to provide in `DESIGN.md`: CI plays the cluster, and the chart still installs none of it.

Add-ons come from their own projects' Helm charts, pinned to a version: KEDA from `kedacore`, ingress-nginx, cert-manager from `jetstack`, and the Traefik and Prometheus Operator CRDs for `extra-objects`. These are the charts those projects publish and maintain, unlike the datastore charts decision 0006 moved away from. Datastores stay plain manifests, and S3 comes from Adobe S3Mock in `ci/fixtures/s3/`.

CI cannot reach Let's Encrypt, so the ingress leg runs a CA issuer under the name the example uses. The licensed legs read the enterprise test licence from repo secrets. Pull requests from forks do not receive those secrets, so the licensed legs are left out there.

## Consequences

- An install break in any example fails `install-test` on labelled, bump and release pull requests.
- The checks cover what the chart renders, not what the add-on does later. The KEDA leg proves the ScaledObject is accepted and its HPA reads the queue, not that workers scale out. Fuller behaviour belongs in n8n's end-to-end suite.
- Add-on and fixture versions are pinned in the hooks and fixtures, and move by hand.
- Overlays scale examples down to fit a hosted runner, and switch off what the fixtures cannot provide, such as Postgres TLS. Each overlay says what it changes and why.
