# Contributing to n8n Hosting

## Commit Messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/) for automated versioning. Your commit messages must follow this format:

```
<type>(<scope>): <description>

[optional body]
```

Types:
- `feat` -- new feature (triggers minor version bump)
- `fix` -- bug fix (triggers patch version bump)
- `docs` -- documentation changes
- `refactor` -- code refactoring
- `perf` -- performance improvements
- `chore(no-release)` -- no version bump

Examples:
```
feat(chart): add webhook processor ingress support
fix(worker): add missing extraEnvFrom to worker deployment
docs: update README with OCI install instructions
```

## Chart Development

### Prerequisites

- [Helm](https://helm.sh/docs/intro/install/) 3.12+
- [chart-testing (ct)](https://github.com/helm/chart-testing) for linting

### Local Linting

```bash
helm lint charts/n8n
ct lint --charts charts/n8n --validate-maintainers=false
```

### Template Validation

Render all templates to check for syntax errors and inspect the generated YAML:

```bash
# Render with minimal values
helm template test charts/n8n -f charts/n8n/examples/minimal.yaml

# Render with all features enabled
helm template test charts/n8n -f charts/n8n/examples/production-s3.yaml

# Save output for inspection
helm template test charts/n8n -f charts/n8n/examples/minimal.yaml > /tmp/rendered.yaml
```

### Local Install Test

**Prerequisites:** A local Kubernetes environment with Docker support. Any of these work:
- [OrbStack](https://orbstack.dev/) (recommended for macOS — lightweight, has built-in Kubernetes)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) with Kubernetes enabled
- [kind](https://kind.sigs.k8s.io/) (Kubernetes-in-Docker — requires Docker)

If using kind, create a cluster first: `kind create cluster --name n8n-test`

#### Option A: Standalone mode (quickest — no external dependencies)

This deploys a single n8n pod with SQLite. No PostgreSQL or Redis needed.

```bash
# Create namespace and secrets
kubectl create namespace n8n-test
kubectl create secret generic n8n-secrets -n n8n-test \
  --from-literal=N8N_ENCRYPTION_KEY=$(openssl rand -hex 32) \
  --from-literal=N8N_HOST=localhost \
  --from-literal=N8N_PORT=5678 \
  --from-literal=N8N_PROTOCOL=http

# Install with standalone example
helm install n8n charts/n8n -n n8n-test \
  -f charts/n8n/examples/standalone.yaml

# Wait for the pod to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=main -n n8n-test --timeout=120s

# Access the UI (keep running, Ctrl+C to stop)
kubectl port-forward svc/n8n-main -n n8n-test 5678:5678
```

Open **http://localhost:5678** in your browser.

**Clean up:**

```bash
helm uninstall n8n -n n8n-test
kubectl delete namespace n8n-test
```

#### Option B: Queue mode (full deployment with PostgreSQL + Redis)

This deploys the chart with external PostgreSQL and Redis, plus worker pods — closer to a production setup.

##### 1. Deploy dependencies

```bash
# Create a test namespace
kubectl create namespace n8n-test

# Add the Bitnami Helm repo
helm repo add bitnami https://charts.bitnami.com/bitnami

# Deploy PostgreSQL and Redis
helm install postgres bitnami/postgresql -n n8n-test \
  --set auth.postgresPassword=postgres \
  --set auth.database=n8n
helm install redis bitnami/redis -n n8n-test \
  --set auth.password=redis \
  --set architecture=standalone

# Wait for databases to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n n8n-test --timeout=120s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n n8n-test --timeout=120s
```

##### 2. Create secrets and install the chart

```bash
# Create the required n8n secrets
kubectl create secret generic n8n-secrets -n n8n-test \
  --from-literal=N8N_ENCRYPTION_KEY=$(openssl rand -hex 32) \
  --from-literal=N8N_HOST=localhost \
  --from-literal=N8N_PORT=5678 \
  --from-literal=N8N_PROTOCOL=http

# Install the chart
helm install n8n charts/n8n -n n8n-test \
  --set database.host=postgres-postgresql \
  --set database.user=postgres \
  --set database.passwordSecret.name=postgres-postgresql \
  --set database.passwordSecret.key=postgres-password \
  --set redis.host=redis-master \
  --set redis.passwordSecret.name=redis \
  --set redis.passwordSecret.key=redis-password \
  --set secretRefs.existingSecret=n8n-secrets

# Watch pods come up (Ctrl+C when all show Running/Ready)
kubectl get pods -n n8n-test -w
```

##### 3. Access the UI

The n8n service uses `ClusterIP` by default, so it's only reachable from inside the cluster. Use port-forwarding to access it from your browser:

```bash
kubectl port-forward svc/n8n-main -n n8n-test 5678:5678
```

Then open **http://localhost:5678**. Keep the port-forward running — it will stop when you Ctrl+C.

##### 4. Clean up

```bash
helm uninstall n8n -n n8n-test
helm uninstall redis -n n8n-test
helm uninstall postgres -n n8n-test
kubectl delete namespace n8n-test

# If using kind:
kind delete cluster --name n8n-test
```

You can also let CI do this for you — add the `test-install` label to your PR and the install-test job will run automatically.

### Version Bumps

**Do not manually edit `Chart.yaml` version.** Semantic-release bumps it automatically based on commit messages.

## Pull Requests

- Add the `test-install` label to PRs that change chart templates to trigger a full install test on a kind cluster
- All PRs must pass lint and template validation checks
