# n8n on AWS ECS Fargate 🚀

Production-ready CloudFormation for running n8n in **queue mode with multi-main** on ECS Fargate, using an ALB and managed data stores that scale with your load. A serverless-container option for teams standardized on ECS, complementing the Kubernetes paths: the [Helm chart](../../charts/n8n) in this repo and the [`terraform-aws-n8n`](https://github.com/n8n-io/terraform-aws-n8n) EKS module.

Three templates, one tier ladder. Start simple, step up when you actually need to.

## Which template to use

Tiers below map to the equivalent [`terraform-aws-n8n`](https://github.com/n8n-io/terraform-aws-n8n) EKS module sizing.

| Template | Reach for it when | EKS module tier |
|---|---|---|
| `n8n-w-multimain-queuemode.yaml` | Dev, small, or cost-sensitive. Multi-main + queue mode on a single RDS instance. | Small (sized up = Medium) |
| `n8n-w-multimain-queuemode-webhooks.yaml` | Production with real webhook load. Adds a dedicated webhook tier, queue-depth worker autoscaling, request-rate webhook autoscaling, and DB / Redis / graceful-shutdown / readiness hardening. | Medium |
| `n8n-w-multimain-queuemode-webhooks-ha.yaml` | Failover-sensitive production. Aurora PostgreSQL, **experimental**, see below (writer + reader, ~6s failover vs ~3 min on single RDS), Redis Multi-AZ, higher floors, larger tasks. | Large (architecture parity) |

> Heads up: these templates use **Enterprise-licensed** n8n features (multi-main and S3 external storage), so the stack will not start without a valid `N8nLicenseKey`. The placeholder default is there for inspection only.

> Aurora is experimental: the HA template runs Aurora PostgreSQL for its faster failover. Aurora is PostgreSQL-compatible rather than upstream PostgreSQL, so n8n does not test or certify it and the Postgres version policy does not cover it. The other two templates run RDS PostgreSQL, which does.

## Architecture

Every template deploys:

- An internet-facing Application Load Balancer with an HTTPS listener and HTTP-to-HTTPS redirect.
- An ECS Fargate service for n8n main tasks behind the load balancer.
- An ECS Fargate service for n8n worker tasks that consume jobs from Redis.
- Amazon RDS PostgreSQL for the n8n database, or Aurora PostgreSQL (experimental) on the HA tier.
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

## Upgrading existing stacks

The templates pin the database engine and the n8n image directly in the resource definitions (they are not stack parameters), so new stacks deploy on known-good versions. If you are updating a stack created from an earlier version of the base template, review the change set first, these pins can force a modify or a downgrade:

- **RDS / Aurora `EngineVersion` `16.x` -> `18.4`**: a **major** engine upgrade, so follow the AWS guide, [RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_UpgradeDBInstance.PostgreSQL.html) or [Aurora](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/USER_UpgradeDBInstance.PostgreSQL.html) for the HA tier. `16.9` upgrades directly to `18.4` on both, no intermediate version. Two things that guide cannot tell you: `EngineVersion` is a hardcoded property here rather than a stack parameter, so edit it in the template before deploying the change set, and CloudFormation cannot apply a version below the one the instance is already on, so if `AutoMinorVersionUpgrade` moved it past the pin the update rolls back. To stay put, pin `17.x` or `16.x`, both are within n8n's compatibility range.
- **n8n image `latest` -> a pinned tag**: the image tag is likewise hardcoded in the container definitions, not a parameter. A stack that already pulled a newer n8n and ran its database migrations will crash-loop if the pin resolves to an older image, because n8n does not down-migrate the schema. Edit the tag to the version currently running (or newer), never older.

New stacks are unaffected, they start directly on the pinned versions.
