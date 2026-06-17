# n8n on AWS ECS Fargate

This directory contains a CloudFormation example for running n8n on ECS Fargate with multi-main queue mode.

## Architecture

The template deploys:

- An internet-facing Application Load Balancer with HTTPS listener and HTTP-to-HTTPS redirect.
- An ECS Fargate service for n8n main tasks behind the load balancer.
- An ECS Fargate service for n8n worker tasks that consume jobs from Redis.
- Amazon RDS PostgreSQL for the n8n database.
- Amazon ElastiCache Redis for queue mode.
- Amazon S3 for binary data storage.
- Secrets Manager secrets for n8n license, encryption key, database credentials, and Redis password.

Workers are not attached to the load balancer. They process queued executions from Redis and do not receive inbound HTTP requests.

## Deployment Inputs

Before deploying, provide:

- A Route 53 hosted zone ID.
- The n8n hostname to create in that hosted zone.
- An ACM certificate ARN in the same AWS Region as the stack.
- Production-grade database, Redis, license, and password values.

The template includes placeholder defaults for some secrets so it is easy to inspect, but those values should be replaced before using the stack for a real deployment.

## Worker Scaling

The worker ECS service uses Application Auto Scaling target tracking. By default it scales on ECS service average CPU and memory:

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

Queue-depth scaling is useful for n8n queue mode, but this template does not implement it directly.

ElastiCache publishes cache and node-level metrics, not the Bull queue backlog key (`bull:default:wait`) that n8n workers consume. The template enables `N8N_METRICS=true` and `N8N_METRICS_INCLUDE_QUEUE_METRICS=true`, so n8n can expose queue metrics such as `n8n_scaling_mode_queue_jobs_waiting` from `/metrics`.

To scale ECS workers from queue depth, publish a queue backlog metric to CloudWatch first. Common approaches are:

- A Prometheus, OpenTelemetry, or CloudWatch agent pipeline that scrapes n8n `/metrics`.
- A scheduled Lambda or small worker that reads the Redis queue length and publishes a custom CloudWatch metric.

After that metric exists, add an Application Auto Scaling custom metric policy. Prefer a backlog-per-worker target instead of raw queue depth so scaling remains proportional to running capacity.

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
