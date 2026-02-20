# n8n Helm Chart

Production-grade Helm chart for [n8n](https://n8n.io), the workflow automation platform. Supports queue mode, multi-main HA, webhook processors, task runners, HPA, PDB, network policies, and S3 external storage.

## Prerequisites

- Helm 3.12+
- Kubernetes 1.25+

**Queue mode** (default): requires external PostgreSQL and Redis — this chart does not bundle them.
**Standalone mode**: no external dependencies; uses SQLite with a PersistentVolumeClaim.

## Install

```bash
# OCI registry (recommended)
helm install n8n oci://ghcr.io/n8n-io/n8n --version 1.0.0 -f my-values.yaml
```

## Quick Start

1. **Set up external services** — PostgreSQL and Redis for queue mode (not needed for standalone mode)

2. **Create required secrets:**
   ```bash
   ./examples/create-secrets.sh
   ```

3. **Choose a values file** from the [examples](./examples/) directory and customize it

4. **Deploy:**
   ```bash
   helm install n8n oci://ghcr.io/n8n-io/n8n --version 1.0.0 -f my-values.yaml
   ```

## Architecture

This chart supports two deployment modes:

- **Queue mode** (default) — main + workers + optional webhook processors. Requires external PostgreSQL and Redis.
- **Standalone mode** — single pod with SQLite. No external dependencies. Suitable for development and small-scale use.

In queue mode, three pod types are supported:

| Component | Purpose | Scaling |
|---|---|---|
| **main** | UI, API, non-production webhooks | 1 replica (or N with multi-main + Enterprise license) |
| **worker** | Executes workflows from Redis queue | 2+ replicas, stateless |
| **webhook-processor** | Handles production webhooks (optional) | 2+ replicas, stateless |

All three use the same n8n container image, differentiated by command/args.

## Examples

| File | Use case |
|---|---|
| [standalone.yaml](./examples/standalone.yaml) | Single pod with SQLite, no external dependencies |
| [minimal.yaml](./examples/minimal.yaml) | Single main pod, minimum config |
| [minimal-with-docker.yaml](./examples/minimal-with-docker.yaml) | Quick testing with Docker Postgres/Redis |
| [multi-main-queue.yaml](./examples/multi-main-queue.yaml) | Multi-main HA (Enterprise license required) |
| [production-s3.yaml](./examples/production-s3.yaml) | Production with S3, HPA, multi-main |

## Secret Management

1. **Core secrets** (`secretRefs.existingSecret`): `N8N_ENCRYPTION_KEY`, `N8N_HOST`, `N8N_PORT`, `N8N_PROTOCOL` — always required
2. **Database password** (`database.passwordSecret`): PostgreSQL password — queue mode only
3. **Redis password** (`redis.passwordSecret`): optional, for authenticated Redis — queue mode only

For production, use an external secrets operator (e.g., [External Secrets Operator](https://external-secrets.io/)) rather than storing secrets in values files.

## Key Configuration

| Value | Description | Default |
|---|---|---|
| `image.repository` | n8n image | `docker.n8n.io/n8nio/n8n` |
| `image.tag` | n8n version | `1.110.1` |
| `queueMode.workerReplicaCount` | Number of worker pods | `2` |
| `queueMode.workerConcurrency` | Jobs per worker | `10` |
| `multiMain.enabled` | Multi-main HA (Enterprise) | `false` |
| `webhookProcessor.enabled` | Dedicated webhook pods | `false` |
| `taskRunners.enabled` | Task runner sidecars | `false` |
| `ingress.enabled` | Create Ingress resource | `false` |
| `persistence.enabled` | PVC for main pods | `false` |
| `hpa.main.enabled` | HPA for main pods | `false` |
| `hpa.worker.enabled` | HPA for worker pods | `false` |
| `networkPolicy.enabled` | Network policies | `false` |

See [values.yaml](./values.yaml) for the full list of configurable values.

## Upgrading

Chart version bumps are automated via semantic-release. Check the [CHANGELOG](../../CHANGELOG.md) for breaking changes before upgrading.

```bash
helm upgrade n8n oci://ghcr.io/n8n-io/n8n --version <new-version> -f my-values.yaml
```
