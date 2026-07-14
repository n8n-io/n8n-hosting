# n8n on AWS ECS Fargate, ecs-fargate-0.1.1 (BETA)

> **BETA / SA sign-off.** Beta release, validated on real AWS but not yet GA. The `0.x` version signals
> early/unstable: defaults and parameters may change. Read the "Beta caveats" below before production use.

## What's new in 0.1.1

- Clarified that a valid **n8n Enterprise license is required**: multi-main and S3 external storage are
  Enterprise-licensed features, so the stack will not start without a real `N8nLicenseKey`. No template
  changes from 0.1.0.

CloudFormation templates to run n8n in **queue mode with multi-main** on ECS Fargate (VPC, ALB, RDS/Aurora
PostgreSQL, ElastiCache Redis, S3 binary storage, Secrets Manager, autoscaling). A tier ladder, start
simple, step up as you need a dedicated webhook tier, faster failover, or native Python.

## Which template to use

| Template | Use when | Roughly equals (EKS module tier) |
|---|---|---|
| `n8n-w-multimain-queuemode.yaml` | Dev / small / cost-sensitive. Multi-main + queue mode, single RDS. | Small (sized up = Medium) |
| `n8n-w-multimain-queuemode-webhooks.yaml` | Production with real webhook load. Adds a dedicated webhook tier, queue-depth worker autoscaling, request-rate webhook autoscaling, and DB/Redis/shutdown/readiness hardening. | Medium |
| `n8n-w-multimain-queuemode-webhooks-ha.yaml` | Failover-sensitive production. Aurora PostgreSQL (writer + reader, ~6s failover vs ~3 min single-RDS), Redis Multi-AZ, higher floors, larger tasks. | Large (architecture parity) |

## Pinned versions

All container images are pinned (no `:latest`): `n8nio/n8n` and `n8nio/runners` = **2.23.4** (the validated
version; they must match), RDS cert-fetcher = `amazonlinux:2023`, worker-scaler Lambda = `python3.12`.

## Key parameters (tuneable; sensible defaults)

- **License (required):** `N8nLicenseKey` must be a **valid n8n Enterprise license**. These templates use
  Enterprise-licensed features (multi-main and S3 external storage); the placeholder default will not work
  and the stack will fail to start without a real key.
- **Worker autoscaling:** `WorkerMinTasks` / `WorkerMaxTasks` / `WorkerBacklogPerTask` / `WorkerConcurrency`
  (queue-depth based, the webhooks/HA templates).
- **Webhook autoscaling:** `WebhookMinTasks` / `WebhookMaxTasks` / `WebhookRequestsPerTask`.
- **Database:** `DBInstanceClass` (size to load; `db.m7g.large` ~250 rps). HA tier uses Aurora `db.r6g.large`+.
- **Redis HA:** `RedisReplicasPerNodeGroup` (0 = single node; >=1 = Multi-AZ + auto-failover).
- **Data retention:** `ExecutionsDataMaxAge` / `ExecutionsDataMaxCount` / `ConcurrencyProductionLimit`.
- **Python Code nodes (beta):** `EnablePythonTaskRunner` (default false). When true, also set
  `PythonStdlibAllow` / `PythonExternalAllow` (e.g. `*` or `json,math`) to allow imports (default = none).

## Deploy outline

Prerequisites: a Route53 hosted zone you control, an ACM certificate **in the same region as the stack**
for your chosen hostname, and a **valid n8n Enterprise license** (multi-main and S3 external storage are
Enterprise-licensed features, so the stack will fail to start without a real `N8nLicenseKey`).

```bash
# templates are > 51,200 bytes, so stage in S3 and deploy by URL
aws s3 cp n8n-w-multimain-queuemode-webhooks.yaml s3://<your-bucket>/
aws cloudformation create-stack \
  --stack-name n8n \
  --template-url https://<your-bucket>.s3.<region>.amazonaws.com/n8n-w-multimain-queuemode-webhooks.yaml \
  --parameters ParameterKey=N8nHostedZone,ParameterValue=<zoneId> \
               ParameterKey=N8nCertArn,ParameterValue=<acmArn> \
               ParameterKey=N8nHostRecordName,ParameterValue=<host> \
               ParameterKey=MasterUserPassword,ParameterValue=<strong-pw> \
               ParameterKey=RedisPassword,ParameterValue=<strong-pw-16+> \
               ParameterKey=N8nLicenseKey,ParameterValue=<key> \
  --capabilities CAPABILITY_NAMED_IAM --region <region>
```

n8n is reachable at `https://<host>` once the stack is `CREATE_COMPLETE` and targets are healthy.

## Beta caveats (what is and isn't proven)

**Validated on a live AWS deploy:** queue-depth worker autoscaling, request-rate webhook autoscaling,
`db.m7g.large` sustaining ~250 rps at p95 ~723 ms, task-crash self-heal, zero-downtime rolling deploys
(readiness-gated), Aurora failover ~6s vs ~3 min single-RDS, and the opt-in Python runner (import-free +
`import sys/json/math`, 200/200 under a burst).

**Known limits for this beta:**
- Throughput numbers used a **trivial** workflow (best case). Re-measure with a representative workflow.
- Aurora failover is a **single run (n=1)**; the HA-tier throughput band is **inferred** from base-tier load
  tests, not separately load-tested.
- The **Python task runner is beta**; imports are off by default and require setting the allowlist params.
- A lower-cost **RDS Multi-AZ DB cluster** alternative to Aurora is documented but not built/measured.
- Validated in one AWS account/region; validate in your own environment before production.

Questions / issues: contact your n8n Solutions Architect.
