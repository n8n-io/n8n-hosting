# n8n on AWS ECS Fargate 🚀

Production-ready CloudFormation for running n8n in **queue mode with multi-main** on ECS Fargate, using an ALB and managed data stores that scale with your load. A serverless-container option alongside the EKS module for teams already standardized on ECS.

Three templates, one tier ladder. Start simple, step up when you actually need to.

## Which template to use

| Template | Reach for it when | EKS-module equivalent |
|---|---|---|
| `n8n-w-multimain-queuemode.yaml` | Dev, small, or cost-sensitive. Multi-main + queue mode on a single RDS instance. | Small (sized up = Medium) |
| `n8n-w-multimain-queuemode-webhooks.yaml` | Production with real webhook load. Adds a dedicated webhook tier, queue-depth worker autoscaling, request-rate webhook autoscaling, and DB / Redis / graceful-shutdown / readiness hardening. | Medium |
| `n8n-w-multimain-queuemode-webhooks-ha.yaml` | Failover-sensitive production. Aurora PostgreSQL (writer + reader, ~6s failover vs ~3 min on single RDS), Redis Multi-AZ, higher floors, larger tasks. | Large (architecture parity) |

> Heads up: these templates use **Enterprise-licensed** n8n features (multi-main and S3 external storage), so the stack will not start without a valid `N8nLicenseKey`. The placeholder default is there for inspection only.

## Architecture

Every template deploys:

- An internet-facing Application Load Balancer with an HTTPS listener and HTTP-to-HTTPS redirect.
- An ECS Fargate service for n8n main tasks behind the load balancer.
- An ECS Fargate service for n8n worker tasks that consume jobs from Redis.
- Amazon RDS PostgreSQL (or Aurora, on the HA tier) for the n8n database.
- Amazon ElastiCache Redis for queue mode.
- Amazon S3 for binary data storage.
- Secrets Manager secrets for the n8n license, encryption key, database credentials, and Redis password.

The `-webhooks` and `-ha` templates add a dedicated webhook service so production webhook traffic never competes with the editor and REST API on the main tasks.

Workers are never attached to the load balancer. They quietly drain the queue from Redis and receive no inbound HTTP traffic.

## Deployment Inputs

Before deploying, provide:

- A Route 53 hosted zone ID.
- The n8n hostname to create in that hosted zone.
- An ACM certificate ARN in the same AWS Region as the stack.
- Production-grade database, Redis, license, and password values.

The template includes placeholder defaults for some secrets so it is easy to inspect, but those values should be replaced before using the stack for a real deployment.

## Worker Scaling

The worker ECS service uses Application Auto Scaling target tracking. On the base template it scales on ECS service average CPU and memory (the `-webhooks` and `-ha` templates add queue-depth scaling on top, see below):

- `WorkerCpuTargetPercent`, default `60`.
- `WorkerMemoryTargetPercent`, default `70`.
- `WorkerScaleInCooldownSeconds`, default `60`.
- `WorkerScaleOutCooldownSeconds`, default `60`.

The current worker capacity knobs are:

- `MainDesiredCount`, default `2`.
- `WorkerDesiredCount`, default `3`.
- `WorkerMinCapacity`, default `2`.
- `WorkerMaxCapacity`, default `10`.
- `WorkerConcurrency`, default `10`.

Set `WorkerDesiredCount` between `WorkerMinCapacity` and `WorkerMaxCapacity`. Effective execution capacity is roughly:

```text
running worker tasks * WorkerConcurrency
```

n8n recommends worker concurrency of 5 or higher. Very low concurrency with many workers can increase database connection pressure without improving throughput.

## Queue-Depth Scaling

Queue-depth scaling matters in queue mode: lightweight jobs can saturate worker concurrency without ever moving CPU, so a CPU-only policy watches the backlog grow and never reacts. The `-webhooks` and `-ha` templates solve this out of the box.

Those templates ship a 1-minute in-VPC Lambda that reads the Bull backlog key from Redis and publishes a `WorkerBacklogPerTask` custom metric, wired to an Application Auto Scaling target-tracking policy. The target is backlog **per worker** rather than raw depth, so scaling stays proportional to running capacity. CPU and memory policies remain as a safety net. Tune it with `WorkerMinTasks`, `WorkerMaxTasks`, `WorkerBacklogPerTask`, and `WorkerConcurrency`.

The base template leaves this out (CPU/memory scaling only) to stay minimal. If you want to add it there, n8n already exposes queue metrics: the template sets `N8N_METRICS=true` and `N8N_METRICS_INCLUDE_QUEUE_METRICS=true`, so `n8n_scaling_mode_queue_jobs_waiting` is available from `/metrics`. Publish a backlog metric to CloudWatch (scrape `/metrics`, or read the Redis queue length from a small Lambda) and attach a custom-metric scaling policy, the same pattern the `-webhooks` template automates.

## Monitoring

Monitor at least:

- ECS worker CPU and memory utilization.
- ECS worker desired, running, and pending task counts.
- RDS CPU, storage, and database connections.
- ElastiCache CPU, memory, evictions, and connections.
- n8n queue waiting, active, completed, and failed metrics from `/metrics`.

## Validation

Validate the template before deploying:

```bash
aws cloudformation validate-template \
  --template-body file://aws-cloudformation/ecs-fargate/n8n-w-multimain-queuemode.yaml
```

If available, also run:

```bash
cfn-lint aws-cloudformation/ecs-fargate/n8n-w-multimain-queuemode.yaml
```

For production changes, create and review a CloudFormation change set in a non-production account before applying it.
