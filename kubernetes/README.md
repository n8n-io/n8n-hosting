# n8n-kubernetes-hosting

Get up and running with n8n on the following platforms:

- [AWS](https://docs.n8n.io/hosting/server-setups/aws/)
- [Azure](https://docs.n8n.io/hosting/server-setups/azure/)
- [Google Cloud Platform](https://docs.n8n.io/hosting/server-setups/google-cloud/)

If you have questions after trying the tutorials, check out the [forums](https://community.n8n.io/).

## Prerequisites

Self-hosting n8n requires technical knowledge, including:

- Setting up and configuring servers and containers
- Managing application resources and scaling
- Securing servers and applications
- Configuring n8n

n8n recommends self-hosting for expert users. Mistakes can lead to data loss, security issues, and downtime. If you aren't experienced at managing servers, n8n recommends [n8n Cloud](https://n8n.io/cloud/).

## Configuration

1. Create a new namespace in your Kubernetes cluster

```bash
kubectl create namespace n8n
```

1. Check and or modify the following values:

- Modify Variables in `n8n/configmap.yaml` like `N8N_URL` and `N8N_HOST`.
- Configure Certificate in `n8n/certificate.yaml` and Ingress in `n8n/ingress.yaml` if you want to make n8n publicly accessible.
- Update the `storageClassName` and sizes of both PVCs in `postgres/pvc.yaml` and `n8n/pvc.yaml`

1. Apply the configuration files

```bash
kubectl apply --recursive -f .
```

1. Port forward the n8n service to your local machine or visit the n8n in your browser.

```bash
kubectl port-forward service/n8n-service 5678:5678 -n n8n
```

## Contributions

For common changes, please open a PR to `main` branch and we will merge this
into cloud provider specific branches.

If you have a contribution specific to a cloud provider, please open your PR to
the relevant branch.
