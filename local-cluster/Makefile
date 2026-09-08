CHART       := ../charts/n8n
VALUES      := values.yaml
NAMESPACES  := n8n-1 n8n-2 n8n-3
PIDS_FILE   := .pids
N8N_IMAGE   := n8nio/n8n:local
KEYS_DIR    := $(CURDIR)/.keys

# Isolated kubeconfig — never touches ~/.kube/config
export KUBECONFIG := $(CURDIR)/.kubeconfig

.DEFAULT_GOAL := help

# Support "make logs <namespace>" — treat the trailing word as a variable
ifeq ($(firstword $(MAKECMDGOALS)),logs)
  LOG_NS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(LOG_NS):;@:)
endif

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

.PHONY: generate-keys
generate-keys: ## Generate RSA 2048-bit key pair for token exchange (regenerated on every make up)
	@mkdir -p $(KEYS_DIR)
	@echo "==> Generating RSA key pair in $(KEYS_DIR)..."
	@openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
		-out $(KEYS_DIR)/private.pem 2>/dev/null
	@openssl pkey -in $(KEYS_DIR)/private.pem -pubout \
		-out $(KEYS_DIR)/public.pem 2>/dev/null
	@echo "Keys written to $(KEYS_DIR)/"

.PHONY: preload-images
preload-images: ## Load the local n8n image into the kind node
	@echo "==> Loading $(N8N_IMAGE) into kind node..."
	@kind load docker-image $(N8N_IMAGE) --name n8n-local
	@echo "Image loaded."

.PHONY: up
up: cluster generate-keys preload-images install ## Full setup: create cluster + generate keys + preload image + install all instances + start port-forwards
	@$(MAKE) wait || echo "==> Warning: some pods may still be initialising — run 'make wait' to check"
	@$(MAKE) forward
	@echo ""
	@echo "All instances are up:"
	@echo "  http://localhost:5678  →  n8n-1 (axolotl)"
	@echo "  http://localhost:5679  →  n8n-2 (narwhal)"
	@echo "  http://localhost:5680  →  n8n-3 (dolphin)"

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
		TRUSTED_KEYS=$$(jq -n \
			--arg key "$$(cat $(KEYS_DIR)/public.pem)" \
			'[{"type":"static","kid":"instance-monitoring-key","algorithms":["RS256"],"key":$$key,"issuer":"https://instance-monitoring.local","expectedAudience":"n8n","allowedRoles":["global:admin"]}]'); \
		kubectl create secret generic n8n-token-exchange -n $$ns \
			--from-literal=N8N_TOKEN_EXCHANGE_ENABLED=true \
			--from-literal=N8N_ENV_FEAT_TOKEN_EXCHANGE=true \
			--from-literal="N8N_TOKEN_EXCHANGE_TRUSTED_KEYS=$$TRUSTED_KEYS" \
			--dry-run=client -o yaml | kubectl apply -f -; \
		helm upgrade --install n8n $(CHART) -n $$ns -f $(VALUES) --wait=false; \
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

pods: ## List all pods and their containers across every namespace in the cluster
	@kubectl get pods -A -o custom-columns='NAMESPACE:.metadata.namespace,POD:.metadata.name,CONTAINERS:.spec.containers[*].name,STATUS:.status.phase,READY:.status.containerStatuses[*].ready'

.PHONY: logs
logs: ## Stream logs from a namespace: make logs <namespace>  (n8n-1 | n8n-2 | n8n-3 | monitoring)
	@if [ -z "$(LOG_NS)" ]; then \
		echo "Usage: make logs <namespace>"; \
		echo "  Namespaces: n8n-1, n8n-2, n8n-3, monitoring"; \
		exit 1; \
	fi; \
	case "$(LOG_NS)" in \
		n8n-*) kubectl --kubeconfig .kubeconfig logs -f -l app.kubernetes.io/component=main -n $(LOG_NS) ;; \
		monitoring) kubectl --kubeconfig .kubeconfig logs -f -l app=instance-monitoring -n $(LOG_NS) ;; \
		*) echo "Unknown namespace: $(LOG_NS). Use n8n-1, n8n-2, n8n-3, or monitoring."; exit 1 ;; \
	esac
