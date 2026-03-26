# Local Dev — Three n8n Instances

Spins up three isolated n8n instances in a local Kubernetes cluster, each in its own namespace and accessible on a unique localhost port. **Does not touch your global `~/.kube/config`** — all kubectl and helm commands use an isolated `local-cluster/.kubeconfig` that is created and managed by the Makefile.

| Instance | Namespace | URL |
|----------|-----------|-----|
| n8n-1 | `n8n-1` | http://localhost:5678 |
| n8n-2 | `n8n-2` | http://localhost:5679 |
| n8n-3 | `n8n-3` | http://localhost:5680 |

Each instance runs in standalone mode (SQLite, no PostgreSQL or Redis required). Data is isolated per instance via separate PersistentVolumeClaims.

---

## Prerequisites

| Tool | Install | Notes |
|------|---------|-------|
| `kind` | `brew install kind` | Creates the local cluster; free, open-source, used in this project's CI |
| `kubectl` | `brew install kubectl` | CLI for interacting with the cluster |
| `helm` 3.12+ | `brew install helm` | Already required by this project |
| `openssl` | Pre-installed on macOS | Used to generate encryption keys |

---

## Quick Start

```bash
cd local-cluster

# Create cluster + install all three instances + start port-forwards
make up

# Open instances in your browser
open http://localhost:5678   # n8n-1
open http://localhost:5679   # n8n-2
open http://localhost:5680   # n8n-3
```

Tear down instances (keeps the cluster running for faster restarts):
```bash
make down
```

Full teardown including the cluster:
```bash
make nuke
```

---

## Available Commands

Run from the `local-cluster/` directory:

| Command | Description |
|---------|-------------|
| `make up` | Full setup: create cluster + preload image + install all instances + start port-forwards |
| `make down` | Teardown: stop port-forwards + uninstall instances (cluster stays) |
| `make nuke` | Full teardown: `make down` + delete the kind cluster |
| `make cluster` | Create the kind cluster only (idempotent) |
| `make delete-cluster` | Delete the kind cluster and remove `.kubeconfig` |
| `make preload-images` | Load the local n8n image into the kind node |
| `make install` | Create namespaces, secrets, and install Helm releases (no port-forward) |
| `make uninstall` | Uninstall Helm releases and delete namespaces |
| `make forward` | Start background port-forwards |
| `make unforward` | Stop background port-forwards |
| `make wait` | Wait for all pods to become ready |
| `make status` | Show pod status across all three namespaces |

---

## How It Works

`make up` runs the following steps in sequence:

1. **`make cluster`** — creates a kind cluster named `n8n-local` and writes its kubeconfig to `local-cluster/.kubeconfig`. Idempotent: skips if `.kubeconfig` already exists. The `KUBECONFIG` env var is set to this file for all Makefile commands, so your `~/.kube/config` is never touched.

2. **`make preload-images`** — loads the local `n8nio/n8n:local` image into the kind node via `kind load docker-image`. This avoids an in-cluster registry pull and makes pod startup fast and reliable.

3. **`make install`** — for each of the three namespaces (`n8n-1`, `n8n-2`, `n8n-3`):
   - Creates the namespace (idempotent)
   - Creates an `n8n-secrets` secret with a random encryption key (`N8N_PORT` is always `5678` — the internal listening port)
   - Installs the Helm chart (`charts/n8n`) with standalone values from `values.yaml`

4. **`make wait`** — waits up to 10 minutes for all pods to reach `Ready`

5. **`make forward`** — starts `kubectl port-forward` in the background for each instance, writing process IDs to `.pids`. Logs are written to `logs/<namespace>.log`.

---

## Troubleshooting

**Pod not becoming ready:**
```bash
make status
kubectl --kubeconfig .kubeconfig describe pod -l app.kubernetes.io/component=main -n n8n-1
kubectl --kubeconfig .kubeconfig logs -l app.kubernetes.io/component=main -n n8n-1
```

**Port already in use (`bind: address already in use`):**
```bash
# Find what's using the port (e.g. 5678)
lsof -i :5678
# Kill existing port-forward processes and restart
make unforward
make forward
```

**Port-forward process died (browser shows connection refused):**
```bash
make unforward
make forward
```

**Reinstall a single instance** (e.g. `n8n-2`):
```bash
helm --kubeconfig .kubeconfig uninstall n8n -n n8n-2
helm --kubeconfig .kubeconfig upgrade --install n8n ../charts/n8n -n n8n-2 -f values.yaml
```

**Start fresh:**
```bash
make nuke
make up
```
