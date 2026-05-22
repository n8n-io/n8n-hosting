# Local Dev — Three n8n Instances

Spins up three isolated n8n instances in a local Kubernetes cluster, each in its own namespace and accessible on a unique localhost port. **Does not touch your global `~/.kube/config`** — all kubectl and helm commands use an isolated `local-cluster/.kubeconfig` that is created and managed by the Makefile.

| Instance | Namespace | Identifier | URL |
|----------|-----------|------------|-----|
| n8n-1 | `n8n-1` | `axolotl` | http://localhost:5678 |
| n8n-2 | `n8n-2` | `narwhal` | http://localhost:5679 |
| n8n-3 | `n8n-3` | `dolphin` | http://localhost:5680 |

Each instance runs in standalone mode (SQLite, no PostgreSQL or Redis required). Data is isolated per instance via separate PersistentVolumeClaims.

---

## Prerequisites

| Tool | Install | Notes |
|------|---------|-------|
| `kind` | `brew install kind` | Creates the local cluster |
| `kubectl` | `brew install kubectl` | CLI for interacting with the cluster |
| `helm` 3.12+ | `brew install helm` | Deploys n8n via the local Helm chart |
| `openssl` | Pre-installed on macOS | Generates the token-exchange key pair |
| `jq` | `brew install jq` | Builds the trusted-keys JSON config |

---

## Quick Start

```bash
cd local-cluster

# Create cluster + generate token-exchange keys + install all three instances + start port-forwards
make up

# Open instances in your browser
open http://localhost:5678   # n8n-1 (axolotl)
open http://localhost:5679   # n8n-2 (narwhal)
open http://localhost:5680   # n8n-3 (dolphin)
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
| `make up` | Full setup: create cluster + generate keys + preload image + install all instances + start port-forwards |
| `make down` | Teardown: stop port-forwards + uninstall instances (cluster stays) |
| `make nuke` | Full teardown: `make down` + delete the kind cluster |
| `make cluster` | Create the kind cluster only (idempotent) |
| `make delete-cluster` | Delete the kind cluster and remove `.kubeconfig` |
| `make generate-keys` | Generate a fresh RSA key pair in `.keys/` (also runs as part of `make up`) |
| `make preload-images` | Load the local n8n image into the kind node |
| `make install` | Create namespaces, secrets, and install Helm releases (no port-forward) |
| `make uninstall` | Uninstall Helm releases and delete namespaces |
| `make forward` | Start background port-forwards |
| `make unforward` | Stop background port-forwards |
| `make wait` | Wait for all pods to become ready |
| `make status` | Show pod status across all three namespaces |

---

## Token Exchange

Every `make up` generates a fresh RSA 2048-bit key pair in `.keys/` (gitignored) and configures all three n8n instances to trust it. This enables the [instance-monitoring](instance-monitoring/) service — and any other backend you control — to authenticate against any instance without static API keys, using [OAuth 2.0 Token Exchange (RFC 8693)](https://datatracker.ietf.org/doc/html/rfc8693).

The following environment variables are set on every n8n pod:

| Variable | Value |
|----------|-------|
| `N8N_TOKEN_EXCHANGE_ENABLED` | `true` |
| `N8N_ENV_FEAT_TOKEN_EXCHANGE` | `true` |
| `N8N_TOKEN_EXCHANGE_TRUSTED_KEYS` | JSON array with the generated public key, `kid: instance-monitoring-key`, `iss: https://instance-monitoring.local`, `allowedRoles: ["global:admin"]` |

## Instance Monitoring

The [instance-monitoring](instance-monitoring/) service is a separate Node.js pod that **pulls** usage data from all three n8n instances every 5 minutes using token exchange. It does not require any push-based configuration on the n8n instances — the token exchange setup above is the only prerequisite.

Start it after `make up`:

```bash
# From local-cluster/
cd instance-monitoring
make up
```

The poll interval defaults to 1 minute. Pass `POLL_INTERVAL_MINUTES` to override:

```bash
make up POLL_INTERVAL_SECONDS=300
```

Then open the dashboard:
```bash
open http://localhost:5700/dashboard
```

Stream live poller logs (from `local-cluster/`):
```bash
kubectl --kubeconfig .kubeconfig logs -f -l app=instance-monitoring -n monitoring
```

See [instance-monitoring/README.md](instance-monitoring/README.md) for details.

---

## How It Works

`make up` runs the following steps in sequence:

1. **`make cluster`** — creates a kind cluster named `n8n-local` and writes its kubeconfig to `local-cluster/.kubeconfig`. Idempotent: skips if `.kubeconfig` already exists. The `KUBECONFIG` env var is set to this file for all Makefile commands, so your `~/.kube/config` is never touched.

2. **`make generate-keys`** — generates a fresh RSA 2048-bit key pair to `local-cluster/.keys/` (gitignored). The public key is used to configure token exchange on all three n8n instances; the private key is used by the instance-monitoring service to sign JWTs. Keys are regenerated on every `make up` so the demo always starts with a clean slate.

3. **`make preload-images`** — loads the local `n8nio/n8n:local` image into the kind node via `kind load docker-image`. This avoids an in-cluster registry pull and makes pod startup fast and reliable.

4. **`make install`** — for each of the three namespaces (`n8n-1`, `n8n-2`, `n8n-3`):
   - Creates the namespace (idempotent)
   - Creates `n8n-secrets` with a random encryption key
   - Creates `n8n-token-exchange` with the token-exchange env vars, embedding the freshly generated public key
   - Installs the Helm chart (`charts/n8n`) with values from `values.yaml`, which includes both secrets via `envFrom`

5. **`make wait`** — waits up to 10 minutes for all pods to reach `Ready`

6. **`make forward`** — starts `kubectl port-forward` in the background for each instance, writing process IDs to `.pids`. Logs are written to `logs/<namespace>.log`.

---

## Inspecting Instance Logs

> All commands below must be run from the `local-cluster/` directory, where `.kubeconfig` lives.

**Stream live logs from an instance:**
```bash
kubectl --kubeconfig .kubeconfig logs -f -l app.kubernetes.io/component=main -n n8n-1
```

Replace `n8n-1` with `n8n-2` or `n8n-3` for the other instances.

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
