# Instance Monitoring

A lightweight service that collects daily execution reports from n8n instances running in the local cluster and displays them in a browser dashboard.

It runs as a single pod in a dedicated `monitoring` namespace — separate from the `n8n-1`, `n8n-2`, `n8n-3` namespaces. All three n8n instances send their data to the same service endpoint via cluster-internal DNS.

| Port | Access | Purpose |
|------|--------|---------|
| `5700` | Cluster-internal only (never port-forwarded) | `POST /ingest-data` — receives reports from n8n instances |
| `5701` | Forwarded to `localhost:5700` on your machine | `GET /dashboard` — view ingested data in a browser |

---

## Prerequisites

The local cluster must already be running. If it isn't, start it first from the parent directory:

```bash
cd ..
make up
```

Additionally you need:

| Tool | Install | Notes |
|------|---------|-------|
| `docker` | Docker Desktop or `brew install colima` + `brew install docker` | Builds the monitoring image |
| `kind` | `brew install kind` | Loads the image into the cluster node |

---

## Quick Start

```bash
cd local-cluster/instance-monitoring

# Build image, deploy to cluster, and start port-forward
make up

open http://localhost:5700/dashboard
```

Tear down (removes the monitoring service but leaves the cluster and n8n instances running):

```bash
make down
```

---

## Available Commands

| Command | Description |
|---------|-------------|
| `make up` | Build image + deploy + wait for ready + start port-forward |
| `make down` | Stop port-forward + remove from cluster |
| `make image` | Build Docker image and load it into the kind cluster |
| `make install` | Apply k8s manifests (namespace, PVC, deployment, service) |
| `make uninstall` | Delete k8s manifests |
| `make wait` | Wait for the pod to become ready |
| `make forward` | Start background port-forward (`localhost:5700` → dashboard) |
| `make unforward` | Stop the background port-forward |
| `make status` | Show pod status in the `monitoring` namespace |

---

## Configuring n8n to Send Reports

n8n instances inside the cluster reach the monitoring service via cluster-internal DNS. Configure an HTTP Request node (or a Schedule Trigger + HTTP Request workflow) in any n8n instance to POST to:

```
http://instance-monitoring.monitoring.svc.cluster.local:5700/ingest-data
```

Expected JSON payload:

```json
{
  "interval": {
    "startTime": "2026-03-25T00:00:00.000Z",
    "endTime": "2026-03-25T23:59:59.999Z"
  },
  "totalProdExecutions": 10,
  "n8nVersion": "2.14.10",
  "instanceId": "your-instance-id",
  "instanceIdentifier": "optional-human-readable-name"
}
```

Required fields: `instanceId`, `n8nVersion`, `totalProdExecutions`, `interval`.
`instanceIdentifier` is optional and shown alongside the instance ID on the dashboard.

---

## How It Works

The service runs two HTTP servers in the same Node.js process:

- **Port 5700 (ingest)** — exposed only as a `ClusterIP` service, so it is never reachable from outside the cluster. n8n instances use the cluster-internal DNS name to POST their daily report. Each report is stored in a SQLite database on a PersistentVolumeClaim mounted at `/data`.

- **Port 5701 (dashboard)** — also a `ClusterIP` service, but `make forward` creates a `kubectl port-forward` mapping it to `localhost:5700` on your machine. The dashboard page renders all stored records grouped by `instanceId`, newest first, and auto-refreshes every 30 seconds.

Data persists across pod restarts via the PVC. It is removed when you run `make uninstall` (which deletes the PVC along with the other manifests).

---

## Troubleshooting

**Pod not becoming ready:**
```bash
make status
kubectl --kubeconfig ../.kubeconfig describe pod -l app=instance-monitoring -n monitoring
kubectl --kubeconfig ../.kubeconfig logs -l app=instance-monitoring -n monitoring
```

**Port already in use (`bind: address already in use`):**
```bash
make unforward
make forward
```

**Redeploying after code changes:**
```bash
make down
make up
```

**Start completely fresh (removes all data):**
```bash
make down
make up
```
