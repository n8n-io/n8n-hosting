# n8n-kubernetes-hosting

This repository provides Kubernetes manifests for deploying n8n workflow automation tool in both development and production environments. It uses Kustomize overlays to manage environment-specific configurations.

## Architecture Overview

The production deployment uses a scalable architecture with the following components:

* **n8n UI**: Single pod handling the web interface (Deployment)
* **n8n Workers**: Multiple pods processing workflow executions (Deployment with KEDA autoscaling)
* **Redis**: Queue management for worker coordination (Deployment)
* **Postgres**: Persistence layer for workflow storage (Deployment)

### Key Features

* **UI/Worker Architecture**: Separates web interface and workflow processing for better scalability
* **Autoscaling**: Uses KEDA with Prometheus metrics to scale workers based on queue size
* **Security Hardening**: Non-root execution, network policies, and secret management
* **Resource Management**: Production-grade resource limits and requests
* **Zero-Downtime Updates**: RollingUpdate strategy for all components

## Prerequisites

Self-hosting n8n requires technical knowledge, including:

* Kubernetes cluster administration
* Setting up and configuring containers and orchestration
* Managing application resources and scaling
* Securing Kubernetes workloads
* Configuring n8n and related infrastructure

### Required Components

* Kubernetes cluster (v1.16+)
* Kubectl and Kustomize
* KEDA for autoscaling (v2.0+)
* Prometheus for metrics (optional, required for autoscaling)
* Ingress controller (e.g., nginx-ingress)
* Cert-Manager (optional, for SSL)

## Deployment Structure

The repository is organized using Kustomize overlays:

```
kubernetes/
├── base/                # Base configuration shared across environments
├── overlays/
│   └── production/      # Production-specific configurations
└── configure-keda-prometheus.ps1  # Configuration script
```

### Base Directory

Contains core components:
* n8n UI deployment (single replica)
* n8n worker deployment
* Redis and Postgres deployments
* Services, PVCs, ConfigMaps, and Secrets
* Basic ingress configuration

### Production Overlay

Enhances the base with production-ready configurations:
* Increased worker replicas (3 by default)
* Enhanced resource limits
* Redis security with password authentication
* Network policies for Redis and Postgres
* Security contexts for non-root execution
* Custom hostname through ingress-patch
* KEDA ScaledObject for worker autoscaling

## Deployment Instructions

### Basic Deployment

```bash
# Deploy the production configuration
kubectl apply -k kubernetes/overlays/production
```

### Configuring KEDA and Prometheus

The repository includes a PowerShell script that automatically detects KEDA and Prometheus in your cluster and configures the ScaledObject accordingly:

```powershell
# Run with default settings
.\kubernetes\configure-keda-prometheus.ps1

# Or customize parameters
.\kubernetes\configure-keda-prometheus.ps1 -MinReplicas 3 -MaxReplicas 30 -Threshold 10
```

#### Script Parameters

* `Namespace`: Your n8n namespace (default: "n8n")
* `PromNamespace`: Prometheus namespace (default: "prometheus")
* `ScaledObjectPatchFile`: Path to ScaledObject patch (default: "overlays/production/n8n-worker-scaledobject-patch.yaml")
* `MinReplicas`: Minimum worker replicas (default: 2)
* `MaxReplicas`: Maximum worker replicas (default: 20)
* `MetricName`: Metric name for scaling (default: "n8n_queue_waiting_jobs")
* `Threshold`: Queue size threshold to trigger scaling (default: 5)
* `Query`: Prometheus query (default: "sum(n8n_queue_waiting_jobs)")

## Environment Variables

Key environment variables in the production deployment:

* `EXECUTIONS_MODE=queue`: Enables queue mode for distributed execution
* `QUEUE_BULL_REDIS_HOST`: Points to Redis service
* `QUEUE_HEALTH_CHECK_ACTIVE=true`: Enables worker health checks
* `DB_POSTGRESDB_HOST`: Points to Postgres service
* `N8N_ENCRYPTION_KEY`: From Secret for data encryption

## Resource Allocations

* **n8n UI**: 500Mi-1Gi memory, 500m-1 CPU
* **n8n workers**: 500Mi-1Gi memory, 300m-1 CPU
* **Redis**: 128Mi-256Mi memory, 100m-300m CPU
* **Postgres**: 4Gi-8Gi memory, 2-4 CPU

## Contributions

For common changes, please open a PR to `main` branch and we will merge this
into cloud provider specific branches.

If you have a contribution specific to a cloud provider, please open your PR to
the relevant branch.
