# 0004. Other artefacts report their name, without a version

Date: 2026-10-07
PR: https://github.com/n8n-io/n8n-hosting/pull/226

## Context

n8n reads `N8N_DEPLOYMENT_ARTIFACT` and sends it with the telemetry it already sends, so we can tell which artefact installed n8n. The chart will report `helm-chart/<chart version>` once #224 lands.

This repository has more artefacts than the chart: the Docker Compose stacks, the Docker Caddy stack, the plain Kubernetes manifests and the CloudFormation templates. Without a value, an install from any of them looks the same as a hand-written setup.

Only the chart has a version of its own. The release tooling versions `charts/n8n` and nothing else. The weekly bump keeps every artefact on the same n8n version, and n8n's telemetry already carries that version.

## Decision

Each artefact sets `N8N_DEPLOYMENT_ARTIFACT` to its name, with no version. A variant adds its name to the artefact's, joined with hyphens:

| Artefact | Value |
| --- | --- |
| `docker-compose/withPostgres` | `docker-compose-with-postgres` |
| `docker-compose/withPostgresAndWorker` | `docker-compose-with-postgres-and-worker` |
| `docker-compose/subfolderWithSSL` | `docker-compose-subfolder-with-ssl` |
| `docker-caddy` | `docker-caddy` |
| `kubernetes` | `kubernetes` |
| `aws-cloudformation/ecs-fargate` | `aws-cloudformation-ecs-fargate-queuemode`, `aws-cloudformation-ecs-fargate-queuemode-webhooks`, `aws-cloudformation-ecs-fargate-queuemode-webhooks-ha` |

The format is `<artefact>[/<version>]`. The slash is the version separator, so a name never contains one. If an artefact gets a version later, append `/<version>` to its name.

The variable goes on the n8n containers only: main, worker and webhook processor. The task runners and init containers do not set it.

## Consequences

- Install counts per artefact and variant work from the first release of n8n that reads the variable. Older n8n versions ignore it, so these files can ship first.
- We cannot tell which revision of an artefact an install used. The n8n version is the closest signal.
- Existing installs report the value only after the user pulls the new files and recreates the containers or tasks. For ECS, a stack update rolls the tasks once.
- `N8N_DIAGNOSTICS_ENABLED=false` stops this value along with the rest of the telemetry.
- Renaming a value later splits the counts. Treat these names as stable.
