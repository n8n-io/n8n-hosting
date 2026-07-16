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
helm install n8n oci://ghcr.io/n8n-io/n8n-helm-chart/n8n --version 1.0.0 -f my-values.yaml
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
   helm install n8n oci://ghcr.io/n8n-io/n8n-helm-chart/n8n --version 1.0.0 -f my-values.yaml
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
| [task-runners.yaml](./examples/task-runners.yaml) | Queue mode with task runner sidecars |
| [production-s3.yaml](./examples/production-s3.yaml) | Production with S3, HPA, multi-main |
| [keda-autoscaling.yaml](./examples/keda-autoscaling.yaml) | Redis queue-length scaling with KEDA |
| [https-ingress.yaml](./examples/https-ingress.yaml) | HTTPS Ingress with TLS and webhook processor routing |

## Secret Management

1. **Core secrets** (`secretRefs.existingSecret`): `N8N_ENCRYPTION_KEY`, `N8N_HOST`, `N8N_PORT`, `N8N_PROTOCOL` — always required
2. **Database password** (`database.passwordSecret`): PostgreSQL password — queue mode only
3. **Redis password** (`redis.passwordSecret`): optional, for authenticated Redis — queue mode only

For production, use an external secrets operator (e.g., [External Secrets Operator](https://external-secrets.io/)) rather than storing secrets in values files.

## Ingress and HTTPS

Set `ingress.enabled=true` to create the main Ingress for the n8n UI, API, and test webhooks. Configure `ingress.className`, controller-specific `ingress.annotations`, and `ingress.tls` for HTTPS termination. For cert-manager, add the issuer annotation and set `ingress.tls[].secretName` to the certificate Secret cert-manager should create.

When `webhookProcessor.enabled=true`, enable `ingress.webhookProcessor.enabled` to create a second Ingress for production webhook traffic. The webhook processor Ingress routes `/webhook/`, `/webhook-waiting/`, `/form/`, `/form-waiting/`, and `/mcp/` to webhook processor pods. Test paths such as `/webhook-test/` and `/mcp-test/` stay on the main Ingress.

### MCP Server Trigger with multiple webhook processors

MCP Server Trigger endpoints (`/mcp/`) are served by the webhook processors, so scaling `webhookProcessor.replicaCount` (or its HPA/KEDA) scales MCP alongside regular webhooks — no dedicated single-replica pod or session affinity is required. This relies on n8n's queue-mode/multi-instance MCP support added in **n8n 2.8.0** ([n8n-io/n8n#25147](https://github.com/n8n-io/n8n/pull/25147)), which recreates MCP sessions from Redis and runs tool calls on workers.

Use `ingress.sticky.enabled=true` for nginx cookie affinity, or `service.sessionAffinity.enabled=true` for Kubernetes `ClientIP` affinity. Multi-main deployments require sticky sessions at the load-balancing layer.

See [https-ingress.yaml](./examples/https-ingress.yaml) for a complete HTTPS example.

## Ports and Health Checks

| Component | Port | Health check |
|---|---:|---|
| main | `service.port` (default `5678`) | HTTP liveness `/healthz`; readiness `/healthz/readiness` |
| webhook-processor | `service.port` (default `5678`) | HTTP liveness `/healthz`; readiness `/healthz/readiness` |
| worker | no Service | exec probe checks the `n8n worker` process |
| task runner broker | `taskRunners.broker.port` (default `5679`) | localhost broker used by task runner sidecars |

Workers consume jobs from Redis and do not receive inbound HTTP traffic, so the chart intentionally does not create a Kubernetes Service for worker pods.

## Scaling Guidance

Scale execution throughput with `queueMode.workerReplicaCount` and `queueMode.workerConcurrency`. The built-in HPA can scale main, worker, and webhook processor deployments from CPU and optional memory utilization.

For queue-based scaling, enable `keda.enabled=true` and configure Redis triggers for workers. KEDA creates `ScaledObject` resources for workers, and optionally webhook processors, instead of the built-in worker/webhook HPAs.

Webhook processors are an optional scaling layer for high-volume production webhook traffic. Enable them when webhook load should be isolated from the UI/API main pods, and configure ingress or load-balancer routing as described above.

## ServiceAccount

By default the chart creates a ServiceAccount named `n8n`. To use an externally-managed ServiceAccount (e.g. one created by Terraform for IRSA), set `serviceAccount.create: false` **and** change `serviceAccount.name` to the name of the existing SA:

```yaml
serviceAccount:
  create: false
  name: "my-external-sa"   # must already exist in the release namespace
```

To use the namespace's default ServiceAccount, set `name: ""`. If you set `create: false` without also changing `name` from the chart default `"n8n"`, rendering will fail with a clear error — this prevents pods from being wired to a ServiceAccount that was never created.

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
| `strategy` | Deployment update strategy | `{}` (k8s default) |
| `podLabels` | Extra pod-template labels; overrides `commonLabels` on pods only | `{}` |
| `hpa.main.enabled` | HPA for main pods | `false` |
| `hpa.worker.enabled` | HPA for worker pods | `false` |
| `keda.enabled` | KEDA queue-based autoscaling | `false` |
| `networkPolicy.enabled` | Network policies | `false` |
| `extraContainers` | Additional sidecar containers on main, worker, and webhook-processor pods | `[]` |
| `nodePlacement` | Component-specific node placement overrides | `{}` |
| `extraInitContainers` | Init containers (incl. native sidecars) on all n8n pods | `[]` |
| `dnsPolicy` / `dnsConfig` | Pod DNS policy + configuration for all n8n pods | `""` / `{}` |
| `serviceAccount.automountServiceAccountToken` | Pod-level toggle for ServiceAccount token automount | unset |

See [values.yaml](./values.yaml) for the full list of configurable values.

## Extra containers (sidecars)

Use `extraContainers` to add arbitrary containers to **main**, **worker**, and **webhook-processor** pods (for example log shippers or local proxies). They are rendered after the main n8n container and after the optional [task runner](#task-runners) sidecar. Combine with `extraVolumes` and `extraVolumeMounts` when the sidecar needs shared storage. List entries are passed through Helm `tpl`, so you can reference `{{ .Release.Name }}` and other template variables in string fields.

```yaml
extraContainers:
  - name: log-shipper
    image: busybox:1.36
    args: ["sh", "-c", "while true; do sleep 3600; done"]
```

## Node Placement

Set global `nodeSelector`, `tolerations`, and `affinity` values to apply the same placement rules to all n8n pods. To target a specific deployment, set the matching `nodePlacement.main`, `nodePlacement.worker`, or `nodePlacement.webhookProcessor` value. Component-specific values take precedence; empty component values fall back to the global settings.

```yaml
nodeSelector:
  kubernetes.io/os: linux

nodePlacement:
  worker:
    nodeSelector:
      workload: workers
    tolerations:
      - key: dedicated
        operator: Equal
        value: n8n-workers
        effect: NoSchedule
  webhookProcessor:
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              topologyKey: kubernetes.io/hostname
```

> **Note:** When `multiMain.enabled=true`, the chart emits an automatic pod-anti-affinity rule to spread main replicas across nodes. Setting `nodePlacement.main.affinity` replaces that auto rule — include your own pod-anti-affinity term if you still want main replicas spread.

See [`examples/node-placement.yaml`](./examples/node-placement.yaml) for a complete configuration that pins `main` to a stable node pool and lets workers run on an autoscaling pool.

## Task Runners

Task runners execute user-provided JavaScript and Python code in isolated sidecar containers, separate from the main n8n process. When enabled, each main and worker pod gets a runner sidecar.

**How it works:** The n8n container runs a task broker on port 5679. The runner sidecar connects to this broker over localhost to receive and execute code tasks.

**Enable task runners:**
```yaml
taskRunners:
  enabled: true
  authToken:
    existingSecret: "n8n-runner-token"
    existingSecretKey: "auth-token"
```

Create the auth token secret:
```bash
kubectl create secret generic n8n-runner-token \
  --from-literal=auth-token=$(openssl rand -base64 32)
```

See [task-runners.yaml](./examples/task-runners.yaml) for a complete example including resource tuning and Python runner support.

## KEDA Autoscaling

The built-in HPA scales workers based on CPU utilization. For queue-based workloads, [KEDA](https://keda.sh) can scale workers based on Redis queue length, which is more responsive to actual demand.

When `keda.enabled` is true, the chart creates KEDA `ScaledObject` resources instead of built-in HPAs for workers (and optionally webhook processors). KEDA must be installed in the cluster.

```bash
# Install KEDA
helm install keda kedacore/keda --namespace keda-system --create-namespace
```

```yaml
keda:
  enabled: true
  worker:
    minReplicaCount: 2
    maxReplicaCount: 20
    triggers:
      - type: redis
        metadata:
          listName: "bull:default:wait"
          listLength: "5"
```

See [keda-autoscaling.yaml](./examples/keda-autoscaling.yaml) for a complete example.

## Upgrading

Chart version bumps are automated via semantic-release. Check the [CHANGELOG](../../CHANGELOG.md) for breaking changes before upgrading.

```bash
helm upgrade n8n oci://ghcr.io/n8n-io/n8n-helm-chart/n8n --version <new-version> -f my-values.yaml
```
