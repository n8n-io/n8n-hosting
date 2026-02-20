#!/bin/bash
# n8n Helm Chart - Secret Creation Script
# This script helps create the required Kubernetes secrets for n8n

set -e

echo "n8n Secrets Creation Script"
echo "================================"
echo

prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"

    read -p "$prompt [$default]: " input
    printf -v "$var_name" '%s' "${input:-$default}"
}

prompt_secret() {
    local prompt="$1"
    local var_name="$2"

    read -s -p "$prompt: " input
    echo
    printf -v "$var_name" '%s' "$input"
}

echo "This script will create the following secrets:"
echo "  • n8n-core-secrets (encryption key, host, protocol)"
echo "  • n8n-db-secret (database password)"
echo "  • s3-credentials (AWS S3 secret key, optional)"
echo

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    echo "   Please ensure kubectl is configured correctly"
    exit 1
fi

echo "✅ Connected to Kubernetes cluster: $(kubectl config current-context)"
echo

echo "Please provide the following information:"
echo

echo "=== Core n8n Configuration ==="
prompt_with_default "n8n host (domain/IP where n8n will be accessible)" "localhost" "N8N_HOST"
prompt_with_default "n8n port" "5678" "N8N_PORT"
prompt_with_default "n8n protocol (http/https)" "http" "N8N_PROTOCOL"

N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
echo "Generated new encryption key: ${N8N_ENCRYPTION_KEY:0:16}..."

echo

echo "=== Database Configuration ==="
prompt_secret "Database password (will be hidden)" "DB_PASSWORD"

echo

echo "=== S3 Configuration (Optional) ==="
echo "Do you want to configure S3 credentials? (y/N)"
read -p "Configure S3? [N]: " configure_s3

if [[ "$configure_s3" =~ ^[Yy]$ ]]; then
    prompt_secret "AWS Secret Access Key (will be hidden)" "AWS_SECRET_ACCESS_KEY"
    CREATE_S3_SECRET=true
else
    CREATE_S3_SECRET=false
fi

echo


echo "  Review your configuration:"
echo "  Host: $N8N_HOST"
echo "  Port: $N8N_PORT"  
echo "  Protocol: $N8N_PROTOCOL"
echo "  Encryption key: Generated"
echo "  Database password: [HIDDEN]"
if [ "$CREATE_S3_SECRET" = true ]; then
    echo "  S3 secret key: [HIDDEN]"
fi

echo
read -p "Create these secrets? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "   Cancelled"
    exit 0
fi

echo
echo "   Creating secrets..."

# Create core secrets
echo "Creating n8n-core-secrets..."
kubectl create secret generic n8n-core-secrets \
    --from-literal=N8N_ENCRYPTION_KEY="$N8N_ENCRYPTION_KEY" \
    --from-literal=N8N_HOST="$N8N_HOST" \
    --from-literal=N8N_PORT="$N8N_PORT" \
    --from-literal=N8N_PROTOCOL="$N8N_PROTOCOL" \
    --dry-run=client -o yaml | kubectl apply -f -

# Create database secret
echo "Creating n8n-db-secret..."
kubectl create secret generic n8n-db-secret \
    --from-literal=password="$DB_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -

# Create S3 secret if requested
if [ "$CREATE_S3_SECRET" = true ]; then
    echo "Creating s3-credentials..."
    kubectl create secret generic s3-credentials \
        --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY" \
        --dry-run=client -o yaml | kubectl apply -f -
fi

echo
echo "   Secrets created successfully!"
echo

# Show what was created
echo "  Created secrets:"
kubectl get secrets n8n-core-secrets n8n-db-secret $([ "$CREATE_S3_SECRET" = true ] && echo "s3-credentials") 2>/dev/null || true

echo
echo "  Next steps:"
echo "  1. Choose a values file from the examples/ directory"
echo "  2. Customize it for your environment"
echo "  3. Deploy with: helm install n8n ./charts/n8n -f your-values.yaml"
echo

# Save encryption key to file for backup
echo "   IMPORTANT: Save your encryption key!"
echo "   Your encryption key has been saved to: ./n8n-encryption-key.txt"
echo "   Keep this file safe - you'll need it if you reinstall n8n"
echo "$N8N_ENCRYPTION_KEY" > ./n8n-encryption-key.txt
chmod 600 ./n8n-encryption-key.txt

echo
echo "   Security reminder:"
echo "   • Keep your encryption key safe and backed up"
echo "   • Don't commit secrets to version control" 
echo "   • Consider using external secret management in production"
echo "   • Rotate secrets regularly"