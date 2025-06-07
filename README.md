# n8n-hosting

This repository contains various deployment options for n8n workflow automation tool, including Docker, Docker Compose, and Kubernetes.

## Deployment Options

### Docker Compose
Simple deployment options using Docker Compose for development and small production environments.

* [Basic Setup](docker-compose/)
* [With Postgres](docker-compose/withPostgres/)
* [With Postgres and Worker](docker-compose/withPostgresAndWorker/)

### Docker with Caddy
Deployment option using Docker with Caddy as a reverse proxy.

* [Docker + Caddy](docker-caddy/)

### Kubernetes
Enterprise-grade deployment option with Kustomize overlays for production environments. Features UI/Worker separation, autoscaling via KEDA, and production-ready security hardening.

* [Kubernetes Deployment](kubernetes/)
* [Production Overlay](kubernetes/overlays/production/)
* [KEDA Autoscaling Configuration](kubernetes/configure-keda-prometheus.ps1)

## Getting Started

Choose a deployment option based on your requirements and follow the instructions in the corresponding directory.

For enterprise production deployments, the Kubernetes option offers the most scalability and resilience.
