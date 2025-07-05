# n8n Helm Chart

This Helm chart deploys [n8n](https://n8n.io/) and a PostgreSQL database on Kubernetes. All resources are fully parameterized for flexibility and production-readiness.

## Features
- Deploys n8n and PostgreSQL with configurable images, resources, and environment variables
- All secrets, config, and storage are templated and customizable
- Supports custom namespaces, service types, and ports

## Usage

### 1. Install the chart
```sh
helm install my-n8n ./n8n-helm -f my-values.yaml
```

### 2. Configuration
Edit `values.yaml` to customize:
- Namespace, PVCs, and storage
- n8n and Postgres images, tags, and resources
- Environment variables and secrets
- Service types and ports

Example:
```yaml
n8n:
  image: n8nio/n8n
  tag: 1.44.0
  replicaCount: 1
  # ...
postgres:
  image: postgres
  tag: "11"
  # ...
```

### 3. Upgrade
```sh
helm upgrade my-n8n ./n8n-helm -f my-values.yaml
```

### 4. Uninstall
```sh
helm uninstall my-n8n
```

## Advanced
- All templates use Helm best practices for parameterization
- You can use conditionals or add subcharts for further customization

---

For more, see the official [n8n docs](https://docs.n8n.io/) and [Helm docs](https://helm.sh/docs/).
