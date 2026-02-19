# n8n Hosting

Official hosting configurations for [n8n](https://n8n.io) -- the workflow automation platform.

## Kubernetes (Helm Chart)

The official n8n Helm chart for production Kubernetes deployments.

```bash
helm install n8n oci://ghcr.io/n8n-io/n8n --version 1.0.0 -f my-values.yaml
```

See the [chart README](./charts/n8n/README.md) for full documentation and the [examples](./charts/n8n/examples/) directory for common configurations.

## Docker Compose

| Directory | Description |
|---|---|
| [docker-compose/withPostgres](./docker-compose/withPostgres/) | n8n + PostgreSQL |
| [docker-compose/withPostgresAndWorker](./docker-compose/withPostgresAndWorker/) | n8n + PostgreSQL + Redis + worker (queue mode) |
| [docker-compose/subfolderWithSSL](./docker-compose/subfolderWithSSL/) | n8n behind SSL reverse proxy in subfolder |
| [docker-caddy](./docker-caddy/) | n8n with Caddy reverse proxy |

## Kubernetes (Raw Manifests)

See [`kubernetes/`](./kubernetes/) for raw Kubernetes manifest examples used in cloud provider tutorials (AWS, Azure, GCP).

## Documentation

- [n8n docs](https://docs.n8n.io/)
- [Self-hosting guides](https://docs.n8n.io/hosting/)
- [Community forum](https://community.n8n.io/)
