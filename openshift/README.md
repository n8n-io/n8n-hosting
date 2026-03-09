# n8n on OpenShift

Manifests in this folder deploy:

- `n8n` in namespace `n8n`
- PostgreSQL backend (`postgres:18`)
- Persistent volumes for both workloads
- OpenShift `Route` with TLS edge termination

Deployment is managed through `kustomization.yaml`.

## Files in this folder

- `namespace.yaml`: Creates namespace `n8n`
- `postgres-secret.yaml`: PostgreSQL credentials
- `postgres-configmap.yaml`: DB init script to create non-root DB user
- `postgres-claim0-persistentvolumeclaim.yaml`: PostgreSQL PVC (`300Gi`)
- `postgres-deployment.yaml`: PostgreSQL Deployment
- `postgres-service.yaml`: PostgreSQL headless Service (`postgres-service`)
- `n8n-claim0-persistentvolumeclaim.yaml`: n8n PVC (`2Gi`)
- `n8n-deployment.yaml`: n8n Deployment configured for PostgreSQL
- `n8n-service.yaml`: n8n ClusterIP Service
- `n8n-route.yaml`: Public OpenShift Route for n8n

## Prerequisites

- OpenShift cluster access (`oc` logged in)
- Dynamic storage class available for PVC provisioning
- DNS for route host (or host override for testing)

## Required changes before deploy

1. Update PostgreSQL credentials in `postgres-secret.yaml`.
2. Update route hostname in `n8n-route.yaml`:
	- `spec.host: n8n.example.com`
3. Update n8n webhook URL in `n8n-deployment.yaml`:
	- `WEBHOOK_URL=https://n8n.example.com/`

Recommended:

- Pin image tags instead of using floating tags (`n8nio/n8n`, `postgres:18`).
- Right-size PostgreSQL resources and storage (`300Gi` may be larger than needed in small labs).

## Deploy

From this folder:

```bash
oc apply -k .
```

## Verify

```bash
oc get all -n n8n
oc get pvc -n n8n
oc get route n8n-web -n n8n
```

Wait until both Deployments are available:

```bash
oc rollout status deploy/postgres -n n8n
oc rollout status deploy/n8n -n n8n
```

## Access

Open the route host configured in `n8n-route.yaml` (for example `https://n8n.example.com`).

## Cleanup

```bash
oc delete -k .
```
