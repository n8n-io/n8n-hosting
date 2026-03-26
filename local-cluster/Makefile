CHART       := ../charts/n8n
VALUES      := values.yaml
NAMESPACES  := n8n-1 n8n-2 n8n-3
PIDS_FILE   := .pids
N8N_IMAGE   := n8nio/n8n:local

# Set MONITORING=1 to configure n8n instances to report to the local instance-monitoring service.
# Requires the instance-monitoring service to be running (see local-cluster/instance-monitoring/).
MONITORING  ?= 0

# Isolated kubeconfig — never touches ~/.kube/config
export KUBECONFIG := $(CURDIR)/.kubeconfig

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# ── Cluster lifecycle ─────────────────────────────────────────────────────────

.PHONY: cluster
cluster: ## Create a local kind cluster with an isolated kubeconfig
	@if [ -f $(KUBECONFIG) ]; then \
		echo "==> Cluster already exists (.kubeconfig found). Skipping creation."; \
	else \
		kind create cluster --name n8n-local --kubeconfig $(KUBECONFIG); \
	fi

.PHONY: delete-cluster
delete-cluster: ## Delete the local kind cluster and remove the kubeconfig
	@kind delete cluster --name n8n-local --kubeconfig $(KUBECONFIG) 2>/dev/null || true
	@rm -f $(KUBECONFIG)
	@echo "Cluster deleted."

# ── Full lifecycle ────────────────────────────────────────────────────────────

.PHONY: preload-images
preload-images: ## Load the local n8n image into the kind node
	@echo "==> Loading $(N8N_IMAGE) into kind node..."
	@kind load docker-image $(N8N_IMAGE) --name n8n-local
	@echo "Image loaded."

.PHONY: up
up: cluster preload-images install ## Full setup: create cluster + preload image + install all instances + start port-forwards
	@$(MAKE) wait || echo "==> Warning: some pods may still be initialising — run 'make wait' to check"
	@$(MAKE) forward
	@echo ""
	@echo "All instances are up:"
	@echo "  http://localhost:5678  →  n8n-1"
	@echo "  http://localhost:5679  →  n8n-2"
	@echo "  http://localhost:5680  →  n8n-3"

.PHONY: down
down: unforward uninstall ## Teardown: stop port-forwards + uninstall all instances (keeps cluster)

.PHONY: nuke
nuke: down delete-cluster ## Full destruction: teardown + delete the kind cluster

# ── Install / Uninstall ───────────────────────────────────────────────────────

.PHONY: install
install: ## Create namespaces, secrets, and install Helm releases
	@for ns in $(NAMESPACES); do \
		case $$ns in \
			n8n-1) port=5678; identifier=axolotl ;; \
			n8n-2) port=5679; identifier=narwhal ;; \
			n8n-3) port=5680; identifier=dolphin ;; \
		esac; \
		echo "==> Installing $$ns (localhost:$$port)"; \
		kubectl create namespace $$ns --dry-run=client -o yaml | kubectl apply -f -; \
		kubectl create secret generic n8n-secrets -n $$ns \
			--from-literal=N8N_ENCRYPTION_KEY=$$(openssl rand -hex 32) \
			--from-literal=N8N_HOST=localhost \
			--from-literal=N8N_PORT=5678 \
			`# N8N_PORT is always 5678 — the internal listening port of the n8n process.` \
			`# The chart injects this key via secretKeyRef; n8n uses it to bind its HTTP server.` \
			`# External ports (5679, 5680 for n8n-2/3) are handled solely by kubectl port-forward` \
			`# and must NOT be set here — doing so causes the readiness probe (which checks 5678)` \
			`# to fail, leaving those pods permanently non-Ready.` \
			--from-literal=N8N_PROTOCOL=http \
			--dry-run=client -o yaml | kubectl apply -f -; \
		if [ -f .env ]; then \
			kubectl create secret generic n8n-env-file -n $$ns \
				--from-env-file=.env \
				--dry-run=client -o yaml | kubectl apply -f -; \
		fi; \
		extra_args=""; \
		if [ "$(MONITORING)" = "1" ]; then \
			extra_args="-f monitoring-values.yaml --set-string config.extraEnv[3].name=N8N_WORKFLOW_EXECUTION_DATA_REPORTING_INSTANCE_IDENTIFIER --set-string config.extraEnv[3].value=$$identifier"; \
		fi; \
		helm upgrade --install n8n $(CHART) -n $$ns -f $(VALUES) $$extra_args --wait=false; \
	done

.PHONY: uninstall
uninstall: ## Uninstall Helm releases and delete namespaces
	@for ns in $(NAMESPACES); do \
		echo "==> Removing $$ns"; \
		helm uninstall n8n -n $$ns --ignore-not-found 2>/dev/null || true; \
		kubectl delete namespace $$ns --ignore-not-found; \
	done

# ── Port-forwards ─────────────────────────────────────────────────────────────

.PHONY: forward
forward: ## Start background port-forwards for all instances
	@if [ -f $(PIDS_FILE) ]; then \
		echo "Port-forwards already running ($(PIDS_FILE) exists). Run 'make unforward' first."; \
		exit 1; \
	fi
	@mkdir -p logs
	@for ns in $(NAMESPACES); do \
		case $$ns in \
			n8n-1) port=5678 ;; \
			n8n-2) port=5679 ;; \
			n8n-3) port=5680 ;; \
		esac; \
		echo "==> Forwarding localhost:$$port → $$ns/n8n-main:5678"; \
		kubectl port-forward svc/n8n-main -n $$ns $$port:5678 > logs/$$ns.log 2>&1 & \
		echo $$! >> $(PIDS_FILE); \
	done
	@echo "Port-forwards started. Logs in local-cluster/logs/. Stop with 'make unforward'."

.PHONY: unforward
unforward: ## Stop all background port-forwards
	@if [ ! -f $(PIDS_FILE) ]; then \
		echo "No port-forwards running ($(PIDS_FILE) not found)."; \
	else \
		while IFS= read -r pid; do kill "$$pid" 2>/dev/null || true; done < $(PIDS_FILE); \
		rm -f $(PIDS_FILE); \
		echo "Port-forwards stopped."; \
	fi

# ── Status / Wait ─────────────────────────────────────────────────────────────

.PHONY: wait
wait: ## Wait for all pods to become ready (runs in parallel)
	@echo "==> Waiting for all pods to be ready..."
	@pids=""; \
	for ns in $(NAMESPACES); do \
		kubectl rollout status deployment/n8n-main -n $$ns --timeout=600s & \
		pids="$$pids $$!"; \
	done; \
	failed=0; \
	for pid in $$pids; do wait $$pid || failed=1; done; \
	exit $$failed

.PHONY: status
status: ## Show pod status across all three namespaces
	@for ns in $(NAMESPACES); do \
		echo "==> $$ns"; \
		kubectl get pods -n $$ns 2>/dev/null || echo "  (namespace not found)"; \
		echo ""; \
	done
