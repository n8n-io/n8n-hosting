# n8n Helm Chart Examples

This directory contains common configuration examples for different deployment scenarios. Each example shows a complete values file with explanations of the key settings.

## Available Examples

### Community Examples (No License Required)
- **[standalone.yaml](./standalone.yaml)** - Single pod with SQLite, no external dependencies
- **[minimal.yaml](./minimal.yaml)** - Single main pod with external PostgreSQL and Redis
- **[minimal-with-docker.yaml](./minimal-with-docker.yaml)** - Quick testing with Docker containers

### Enterprise Examples (License Required)
- **[production-s3.yaml](./production-s3.yaml)** - Production setup with multi-main, webhooks, S3 storage, and autoscaling
- **[multi-main-queue.yaml](./multi-main-queue.yaml)** - Multi-main and queue mode configuration


## Important Notice

### External Services
**Queue mode** (default) requires external PostgreSQL and Redis services — this chart does not bundle them.
**Standalone mode** (`queueMode.enabled: false`) uses SQLite with a PersistentVolumeClaim and has no external dependencies — see `standalone.yaml`.

### License Requirements
- **Multi-main setup** (`multiMain.enabled: true`) requires an n8n Enterprise license
- **Community Edition** users should use single main pod configurations

## Quick Start

### 1. Create Required Secrets
```bash
./examples/create-secrets.sh
```

### 2. Choose Your Example
Select the example that best matches your use case from the list above.

### 3. Deploy
```bash
# Copy and customize an example
cp examples/production-s3.yaml my-values.yaml
# Edit my-values.yaml with your settings

# Deploy with Helm
helm install n8n ./charts/n8n -f my-values.yaml
```

For quick testing with Docker:
```bash
# Start PostgreSQL
docker run -d --name n8n-postgres -e POSTGRES_DB=n8n -e POSTGRES_USER=n8n -e POSTGRES_PASSWORD=n8npassword -p 5432:5432 postgres:15

# Start Redis
docker run -d --name n8n-redis -p 6379:6379 redis:7-alpine
```

## 🚀 Quick Start

1. **Set up external services** — PostgreSQL and Redis for queue mode (not needed for standalone mode)
2. Choose the example that matches your scenario
3. Copy the values file: `cp examples/production-s3.yaml my-values.yaml`
4. Customize the values for your environment
5. Create required secrets: `./examples/create-secrets.sh`
6. Deploy: `helm install n8n ./charts/n8n -f my-values.yaml`

## 📋 Configuration Checklist

Before deploying, ensure you have:

- [ ] **Secrets created** (database password, encryption key, etc.)
- [ ] **External services** (PostgreSQL, Redis) if using queue mode
- [ ] **Storage configuration** (S3, GCS, Azure) if using external storage
- [ ] **Network access** configured for your cluster
- [ ] **Resource limits** appropriate for your workload

## 🔧 Customization Guide

### Essential Settings
```yaml
# Always required
secretRefs:
  existingSecret: "n8n-core-secrets"

# Queue mode only (not needed for standalone mode)
database:
  host: "your-postgres-host"
  passwordSecret:
    name: "your-secret"
    key: "password"

redis:
  host: "your-redis-host"
```

### Scaling Configuration
```yaml
# For production workloads
queueMode:
  enabled: true
  workerReplicaCount: 5

multiMain:
  enabled: true
  replicas: 2

# Optional: Dedicated webhook processors (requires load balancer routing)
webhookProcessor:
  enabled: true
  replicaCount: 2
  disableProductionWebhooksOnMainProcess: true

hpa:
  main:
    enabled: true
    maxReplicas: 5
  worker:
    enabled: true 
    maxReplicas: 20
```

### Storage Configuration
```yaml
# S3 Storage (AWS only) - choose authentication method:
s3:
  enabled: true
  bucket:
    name: "your-bucket"
    region: "your-region"
  auth:
    # Option 1: IRSA (recommended for AWS EKS)
    autoDetect: true  # Only works with AWS S3
    
    # Option 2: Access Keys
    # autoDetect: false
    # accessKeyId: "YOUR_ACCESS_KEY"
    # secretAccessKeySecret:
    #   name: "s3-credentials"
    #   key: "secret-access-key"

# Service account (required for IRSA authentication)
serviceAccount:
  awsRoleArn: "arn:aws:iam::ACCOUNT:role/n8n-s3-role"  # Only for autoDetect: true
```

## Troubleshooting

### Common Issues

**Deployment fails with schema validation:**
- Ensure `queueMode.enabled: true` when using `multiMain.enabled: true`
- Set `multiMain.replicas >= 2` when multi-main is enabled

**Connection issues:**
- Enable session affinity: `service.sessionAffinity.enabled: true`
- Check database SSL settings if using cloud databases

**Storage issues:**
- Verify S3 bucket permissions and region
- For IRSA, ensure the service account has the correct role ARN

**Performance issues:**
- Increase worker replicas: `queueMode.workerReplicaCount`
- Enable HPA for automatic scaling
- Consider webhook processors for high webhook throughput

## Webhook Processors

Webhook processors provide dedicated pods for handling production webhooks, improving performance by separating webhook traffic from UI/API workload.

### Configuration Options

**Disabled (Default)**:
```yaml
webhookProcessor:
  enabled: false
```

**Enabled with Dedicated Processing**:
```yaml
webhookProcessor:
  enabled: true
  replicaCount: 2
  disableProductionWebhooksOnMainProcess: true
```

### Load Balancer Requirements

When `disableProductionWebhooksOnMainProcess: true`, configure your load balancer to route:
- `/webhook/*` → webhook processor service (production webhooks)
- `/webhook-test/*` → main service (test webhooks)  
- `/*` → main service (UI, API, everything else)

### Testing
```bash
curl -i http://your-domain/webhook/test-id      # Should reach webhook processor
curl -i http://your-domain/webhook-test/test-id # Should reach main service
```

**Webhook processor returns JSON errors. Main service returns JSON errors or HTML. Wrong routing returns "Cannot POST" errors.**

## Additional Resources

- [n8n Documentation](https://docs.n8n.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
