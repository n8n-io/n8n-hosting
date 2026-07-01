# n8n Hosting

Official hosting configurations for [n8n](https://n8n.io) -- the workflow automation platform.

## Requirements & supported versions

n8n doesn't publish a version-by-version support matrix -- its policy is to support
actively-maintained releases of its dependencies. Use the table below as a starting point and
confirm against the linked n8n docs for the release you're deploying.

| Component | Supported / recommended | Notes |
|---|---|---|
| n8n | Latest stable release | Pin a specific image tag for production rather than relying on `stable`/`latest`. |
| PostgreSQL | Any actively-maintained release | Recommended database for production. n8n documents **13** as the queue-mode minimum, but prefer a still-supported major. |
| SQLite | Bundled | Default when queue mode is off. Fine for development and small single-instance setups. |
| MySQL / MariaDB | **Not supported** | Deprecated as the n8n backend in v1.0 and removed in v2.0 -- use PostgreSQL. (The MySQL *node* is unaffected.) |
| Redis | **7+** recommended | Only needed for queue mode. Redis 6+ is required if you set a Redis username. |
| Valkey | Redis-compatible drop-in for queue mode | Not separately version-guaranteed by n8n; verify against your n8n release. |

For the authoritative details, see:

- [Supported databases and settings](https://docs.n8n.io/hosting/configuration/supported-databases-settings/)
- [Configuring queue mode](https://docs.n8n.io/hosting/scaling/queue-mode/)
- [Queue mode environment variables](https://docs.n8n.io/hosting/configuration/environment-variables/queue-mode/) (Redis)

## Kubernetes (Helm Chart)

The official n8n Helm chart for production Kubernetes deployments.

```bash
helm install n8n oci://ghcr.io/n8n-io/n8n-helm-chart/n8n -f my-values.yaml
```

See the [chart README](./charts/n8n/README.md) for full documentation and the [examples](./charts/n8n/examples/) directory for common configurations.

## Docker Compose

| Directory | Description |
|---|---|
| [docker-compose/withPostgres](./docker-compose/withPostgres/) | n8n + PostgreSQL |
| [docker-compose/withPostgresAndWorker](./docker-compose/withPostgresAndWorker/) | n8n + PostgreSQL + Redis + worker (queue mode) |
| [docker-compose/subfolderWithSSL](./docker-compose/subfolderWithSSL/) | n8n behind SSL reverse proxy in subfolder |
| [docker-caddy](./docker-caddy/) | n8n with Caddy reverse proxy |

## AWS CloudFormation (ECS Fargate)

See [`aws-cloudformation/ecs-fargate/`](./aws-cloudformation/ecs-fargate/) for an AWS ECS Fargate example with multi-main queue mode, RDS PostgreSQL, ElastiCache Redis, S3 binary storage, HTTPS through an Application Load Balancer, and worker autoscaling.

## Kubernetes (Raw Manifests)

See [`kubernetes/`](./kubernetes/) for raw Kubernetes manifest examples used in cloud provider tutorials (AWS, Azure, GCP).

## Documentation

- [n8n docs](https://docs.n8n.io/)
- [Self-hosting guides](https://docs.n8n.io/hosting/)
- [Community forum](https://community.n8n.io/)

## License

This project is licensed under the MIT License -- see [LICENSE.md](./LICENSE.md) for details.
