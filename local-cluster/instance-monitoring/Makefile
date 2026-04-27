MONITORING_IMAGE := instance-monitoring:local
PIDS_FILE        := .pids

# Kubeconfig lives one level up (created by `make cluster` in local-cluster/)
export KUBECONFIG := $(CURDIR)/../.kubeconfig

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# ── Lifecycle ─────────────────────────────────────────────────────────────────

.PHONY: up
up: image install wait forward ## Build image, deploy to cluster, and start port-forward
	@echo ""
	@echo "Instance monitoring is up:"
	@echo "  http://localhost:5700/dashboard  →  dashboard"
	@echo ""
	@echo "n8n ingest URL (cluster-internal):"
	@echo "  http://instance-monitoring.monitoring.svc.cluster.local:5700/ingest-data"

.PHONY: down
down: unforward uninstall ## Stop port-forward and remove from cluster

# ── Image ─────────────────────────────────────────────────────────────────────

.PHONY: cluster
cluster: ## Ensure the kind cluster exists (creates it if not)
	@if kind get clusters 2>/dev/null | grep -q n8n-local; then \
		echo "==> Cluster n8n-local already exists. Skipping creation."; \
	else \
		echo "==> Creating kind cluster n8n-local..."; \
		kind create cluster --name n8n-local --kubeconfig $(KUBECONFIG); \
	fi

.PHONY: image
image: cluster ## Build the Docker image and load it into the kind cluster
	@echo "==> Building $(MONITORING_IMAGE)..."
	@docker build -t $(MONITORING_IMAGE) .
	@echo "==> Loading $(MONITORING_IMAGE) into kind cluster..."
	@kind load docker-image $(MONITORING_IMAGE) --name n8n-local
	@echo "Image loaded."

# ── Install / Uninstall ───────────────────────────────────────────────────────

.PHONY: install
install: ## Apply k8s manifests (namespace, pvc, deployment, service)
	@echo "==> Applying k8s manifests..."
	@kubectl apply -f k8s/namespace.yaml
	@kubectl apply -f k8s/

.PHONY: uninstall
uninstall: ## Delete k8s manifests
	@echo "==> Removing k8s manifests..."
	@kubectl delete -f k8s/ --ignore-not-found

# ── Wait ──────────────────────────────────────────────────────────────────────

.PHONY: wait
wait: ## Wait for the monitoring pod to become ready
	@echo "==> Waiting for instance-monitoring to be ready..."
	@kubectl rollout status deployment/instance-monitoring -n monitoring --timeout=300s

# ── Port-forward ──────────────────────────────────────────────────────────────

.PHONY: forward
forward: ## Start background port-forward for the dashboard (localhost:5700)
	@if [ -f $(PIDS_FILE) ]; then \
		echo "Port-forward already running ($(PIDS_FILE) exists). Run 'make unforward' first."; \
		exit 1; \
	fi
	@mkdir -p logs
	@echo "==> Forwarding localhost:5700 → monitoring/instance-monitoring:5701 (dashboard)"
	@kubectl port-forward svc/instance-monitoring -n monitoring 5700:5701 > logs/monitoring.log 2>&1 & \
		echo $$! > $(PIDS_FILE)
	@echo "Port-forward started. Log: logs/monitoring.log. Stop with 'make unforward'."

.PHONY: unforward
unforward: ## Stop the background port-forward
	@if [ ! -f $(PIDS_FILE) ]; then \
		echo "No port-forward running ($(PIDS_FILE) not found)."; \
	else \
		while IFS= read -r pid; do kill "$$pid" 2>/dev/null || true; done < $(PIDS_FILE); \
		rm -f $(PIDS_FILE); \
		echo "Port-forward stopped."; \
	fi

# ── Status ────────────────────────────────────────────────────────────────────

.PHONY: status
status: ## Show pod status in the monitoring namespace
	@kubectl get pods -n monitoring 2>/dev/null || echo "(monitoring namespace not found)"
