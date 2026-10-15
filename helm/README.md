# 🚀 n8n Self-Hosted on Kubernetes

This repository contains a Helm-based deployment for **n8n**, including a managed **PostgreSQL** instance. It is designed for ease of use in homelab environments, featuring a secure "Global Secret" bridge and automated volume permission handling.

---
## 📋 Table of Contents
1. [Prerequisites](#-prerequisites)
2. [Setup Guide](#-setup-guide)
---
## 🏗 Prerequisites

* **Kubernetes Cluster** (v1.22+)
* **Helm 3** installed
* **NGINX Ingress Controller** (installed and reachable - optional)
* **Default StorageClass** (for PVC automated provisioning)
---

## 🏁 Setup Guide

### 1. Create a Namespace
Isolate your n8n instance from other applications.
```
kubectl create namespace n8n
```
### 2. Apply secret
If needed, change database passwords in the n8n-secrets.yaml file.
```
kubectl apply -f ./helm/n8n-secrets.yaml -n n8n
```
### 3. Apply helm chart
```
helm install ./helm my-n8n -n n8n 
```