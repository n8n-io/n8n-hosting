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

Once something will actually scale a worker or webhook-processor Deployment, the chart stops setting that Deployment's `replicas` and leaves the count to the HPA or the `ScaledObject`. That means KEDA with triggers configured for the component, or the built-in HPA with `keda.enabled` off, since `keda.enabled` replaces the worker and webhook HPAs. Kubernetes defaults the field to 1 on first create and the autoscaler takes over from there, so later upgrades neither reset the count nor show as drift on a GitOps sync.

On the first upgrade from a chart version that set `replicas`, Helm removes the field it used to manage, so an autoscaled Deployment drops to 1 replica once before the autoscaler scales it back up.

`queueMode.workerReplicaCount` and `webhookProcessor.replicaCount` still size the Deployments where nothing else will, and `queueMode.workerReplicaCount: 0` still removes the worker Deployment altogether.

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
| `image.tag` | n8n version | `""` (uses the chart's `appVersion`) |
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
| `keda.worker.pause` | Pause worker autoscaling, freezing workers at their current replica count | `false` |
| `keda.worker.pausedReplicaCount` | Optional replica count to hold whilst paused; only applied when `pause=true` | `null` |
| `keda.webhookProcessor.enabled` | KEDA autoscaling for webhook processor pods | `false` |
| `keda.webhookProcessor.pause` | Pause webhook processor autoscaling, freezing them at their current replica count | `false` |
| `keda.webhookProcessor.pausedReplicaCount` | Optional replica count to hold whilst paused; only applied when `pause=true` | `null` |
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

Task runners execute user-provided JavaScript and Python code in isolated sidecar containers, separate from the main n8n process. When enabled, worker pods get a runner sidecar in queue mode (manual executions are offloaded to workers). In standalone mode (`queueMode.enabled=false`), the main pod gets a runner sidecar instead.

**How it works:** The n8n process that executes workflows runs a task broker on port 5679, and its runner sidecar connects to that broker over localhost to receive and execute code tasks. In queue mode the executing process is the worker, so only worker pods run a broker and get a sidecar. n8n does not start a broker on main pods when manual executions are offloaded to workers, which the chart always enables in queue mode.

**Requires n8n 2.13.0 or later.** Earlier versions also run a broker on main pods, and 1.108.0 to 2.12.x need a runner there for the MCP Server Trigger, so pinning `image.tag` below 2.13.0 leaves those executions without a runner. The chart does not enforce this version floor when `image.tag` is overridden.

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
    pause: false
    minReplicaCount: 2
    maxReplicaCount: 20
    triggers:
      - type: redis
        metadata:
          listName: "bull:jobs:wait"
          listLength: "5"
```

Set `keda.worker.pause: true` to pause worker autoscaling. This adds `autoscaling.keda.sh/paused: "true"` to the worker ScaledObject, and KEDA holds the workers at whatever replica count they are currently running, which is what you want whilst troubleshooting a scaling issue.

To pause and hold a specific count instead, set `pausedReplicaCount`. Setting it to `0` scales workers down entirely:

```yaml
keda:
  worker:
    pause: true
    pausedReplicaCount: 0
```

`pausedReplicaCount` is only applied when `pause: true`, and leaving it unset is what gives you the freeze-at-current behaviour. With both annotations set KEDA scales the workers to the count first, then pauses autoscaling.

Webhook processors have the same pair under `keda.webhookProcessor`, and `pause` on its own freezes them at their current count just as it does for workers. Taking them to zero stops those pods accepting webhook traffic, so treat `pausedReplicaCount: 0` here as a maintenance-window setting rather than the troubleshooting one it is for workers:

```yaml
keda:
  webhookProcessor:
    pause: true
    pausedReplicaCount: 0
```

Webhook processors only autoscale in queue mode, with `keda.enabled`, `webhookProcessor.enabled` and `keda.webhookProcessor.enabled` all set, and at least one trigger of their own. `keda.webhookProcessor.triggers` is empty by default, and the chart fails the install rather than leave you with webhook processors that look autoscaled and are not. To run KEDA for workers alone, leave `keda.webhookProcessor.enabled` off, which is the default. To run it for webhook processors alone, empty `keda.worker.triggers`, since workers have no enabled flag of their own.

Either component merges these annotations with anything you set in `commonAnnotations`. The chart-managed keys win on a collision, so you cannot end up with the same annotation twice.

The `listName` is the Bull waiting-list key, `<prefix>:jobs:wait`, where the prefix defaults to `bull`. If you set `redis.prefix`, update `listName` to match (e.g. `myprefix:jobs:wait`), otherwise the scaler polls a key n8n never writes to and queue-depth autoscaling won't fire.

See [keda-autoscaling.yaml](./examples/keda-autoscaling.yaml) for a complete example.

## Upgrading

Chart version bumps are automated via Release Please. Check the [CHANGELOG](./CHANGELOG.md) for breaking changes before upgrading.

```bash
helm upgrade n8n oci://ghcr.io/n8n-io/n8n-helm-chart/n8n --version <new-version> -f my-values.yaml
```

## Development

The chart's unit tests use the [helm-unittest](https://github.com/helm-unittest/helm-unittest) plugin. From a clone of the repository, run:

```bash
helm unittest --strict charts/n8n
helm unittest --strict --skip-schema-validation -f 'tests/without-schema/*_test.yaml' charts/n8n
```

See [CONTRIBUTING.md](https://github.com/n8n-io/n8n-hosting/blob/main/CONTRIBUTING.md) for how to install the plugin and the other local checks.
