#!/bin/bash
# n8n Helm Chart - Secret Creation Script
# This script helps create the required Kubernetes secrets for n8n

set -eo pipefail

usage() {
    cat <<EOF
Usage: $0 [-n NAMESPACE]

Creates the Kubernetes Secrets that the n8n examples reference.

Options:
  -n, --namespace NAMESPACE  Namespace to create the Secrets in.
                             Defaults to the namespace of the current kubectl context.
  -h, --help                 Show this help.
EOF
}

NAMESPACE=""
while [ $# -gt 0 ]; do
    case "$1" in
        -n|--namespace)
            if [ -z "${2:-}" ]; then
                echo "❌ $1 needs a namespace name"
                exit 1
            fi
            NAMESPACE="$2"
            shift 2
            ;;
        --namespace=*)
            NAMESPACE="${1#*=}"
            if [ -z "$NAMESPACE" ]; then
                echo "❌ --namespace needs a namespace name"
                exit 1
            fi
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

echo "n8n Secrets Creation Script"
echo "================================"
echo

# Reads the value exactly as typed: IFS= keeps leading and trailing spaces,
# and -r keeps backslashes.
prompt_secret() {
    local prompt="$1"
    local var_name="$2"
    local input

    while true; do
        if ! IFS= read -rs -p "$prompt: " input; then
            echo
            echo "❌ No value was entered"
            exit 1
        fi
        echo
        if [ -n "$input" ]; then
            break
        fi
        echo "   The value cannot be empty."
    done
    printf -v "$var_name" '%s' "$input"
}

# Returns 0 if the Secret exists and 1 if it does not. Any other error, such as
# missing permissions, stops the script rather than being read as "not found".
secret_exists() {
    local name="$1"
    local error

    if error=$(kubectl get secret "$name" -n "$NAMESPACE" 2>&1 >/dev/null); then
        return 0
    fi
    if [[ "$error" == *NotFound* ]]; then
        return 1
    fi
    echo "❌ Cannot check for Secret $name in namespace $NAMESPACE:"
    echo "   $error"
    exit 1
}

# Server-side apply creates the Secret or replaces the keys this script sets,
# and does not copy the values into a last-applied-configuration annotation.
# Callers pass each value as --from-file=KEY=<(printf '%s' "$VALUE"), so the
# value reaches kubectl through a pipe rather than its command line.
apply_secret() {
    local name="$1"
    shift

    kubectl create secret generic "$name" -n "$NAMESPACE" "$@" \
        --dry-run=client -o yaml \
        | kubectl apply --server-side --force-conflicts -n "$NAMESPACE" -f -
}

echo "This script will create the following secrets:"
echo "  • n8n-core-secrets (encryption key, task runner token)"
echo "  • n8n-db-secret (database password)"
echo "  • s3-credentials (AWS S3 secret key, optional)"
echo

for tool in kubectl openssl; do
    if ! command -v "$tool" &> /dev/null; then
        echo "❌ $tool is not installed or not in PATH"
        exit 1
    fi
done

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    echo "   Please ensure kubectl is configured correctly"
    exit 1
fi

if [ -z "$NAMESPACE" ]; then
    NAMESPACE=$(kubectl config view --minify -o jsonpath='{..namespace}')
    NAMESPACE=${NAMESPACE:-default}
fi

# Users with access to a single namespace often cannot read Namespace objects,
# so only a NotFound answer stops the script.
if ! ns_error=$(kubectl get namespace "$NAMESPACE" 2>&1 >/dev/null); then
    if [[ "$ns_error" == *NotFound* ]]; then
        echo "❌ Namespace $NAMESPACE does not exist"
        echo "   Create it with: kubectl create namespace $NAMESPACE"
        echo "   Or choose another namespace with: $0 --namespace <namespace>"
        exit 1
    fi
    echo "⚠️  Cannot check that namespace $NAMESPACE exists. Continuing."
fi

echo "✅ Connected to Kubernetes cluster: $(kubectl config current-context)"
echo "   Namespace: $NAMESPACE"
echo

echo "=== S3 Configuration (Optional) ==="
echo "Do you want to configure S3 credentials? (y/N)"
read -p "Configure S3? [N]: " configure_s3

if [[ "$configure_s3" =~ ^[Yy]$ ]]; then
    CREATE_S3_SECRET=true
else
    CREATE_S3_SECRET=false
fi

echo

SECRETS=(n8n-core-secrets n8n-db-secret)
if [ "$CREATE_S3_SECRET" = true ]; then
    SECRETS+=(s3-credentials)
fi

# One confirmation covers the whole set. Replacing only some of the Secrets
# would leave the encryption key backup out of step with the cluster.
EXISTING_SECRETS=()
for secret in "${SECRETS[@]}"; do
    if secret_exists "$secret"; then
        EXISTING_SECRETS+=("$secret")
    fi
done

if [ ${#EXISTING_SECRETS[@]} -gt 0 ]; then
    echo "⚠️  These Secrets already exist in namespace $NAMESPACE:"
    for secret in "${EXISTING_SECRETS[@]}"; do
        echo "  • $secret"
    done
    echo
    if [[ " ${EXISTING_SECRETS[*]} " == *" n8n-core-secrets "* ]]; then
        echo "   Replacing n8n-core-secrets gives n8n a new encryption key."
        echo "   n8n can then no longer decrypt the credentials it has stored."
    fi
    echo "   n8n reads the new values only when its containers restart. Restart the n8n"
    echo "   Deployments afterwards so every container reads the new values together."
    echo

    if [ ! -t 0 ]; then
        echo "❌ Not replacing existing Secrets without a terminal to confirm"
        echo "   Nothing was changed."
        exit 1
    fi

    read -p "To replace all of them, type the namespace name ($NAMESPACE): " confirm_replace
    if [ "$confirm_replace" != "$NAMESPACE" ]; then
        echo "   Cancelled. Nothing was changed."
        exit 0
    fi
    echo
fi

echo "Please provide the following information:"
echo

echo "=== Core n8n Configuration ==="

N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
echo "Generated new encryption key: ${N8N_ENCRYPTION_KEY:0:16}..."

N8N_RUNNERS_AUTH_TOKEN=$(openssl rand -base64 32)
echo "Generated new task runner auth token"

echo

echo "=== Database Configuration ==="
prompt_secret "Database password (will be hidden)" "DB_PASSWORD"

echo

if [ "$CREATE_S3_SECRET" = true ]; then
    echo "=== S3 Configuration ==="
    prompt_secret "AWS Secret Access Key (will be hidden)" "AWS_SECRET_ACCESS_KEY"
    echo
fi

echo "  Review your configuration:"
echo "  Namespace: $NAMESPACE"
echo "  Encryption key: Generated"
echo "  Database password: [HIDDEN]"
if [ "$CREATE_S3_SECRET" = true ]; then
    echo "  S3 secret key: [HIDDEN]"
fi
echo "  Task runner token: Generated"
if [ ${#EXISTING_SECRETS[@]} -gt 0 ]; then
    echo "  Replacing: ${EXISTING_SECRETS[*]}"
fi

echo
read -p "Create these secrets? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "   Cancelled"
    exit 0
fi

echo

# Save the encryption key before writing any Secret, so that if the file
# cannot be written, nothing in the cluster has changed. noclobber refuses to
# overwrite an earlier backup.
KEY_FILE="./n8n-encryption-key-${NAMESPACE}-$(date -u +%Y%m%dT%H%M%SZ).txt"
if ! (set -o noclobber; umask 077; printf '%s\n' "$N8N_ENCRYPTION_KEY" > "$KEY_FILE") 2>/dev/null; then
    echo "❌ Cannot write the encryption key to $KEY_FILE"
    echo "   No Secrets were changed."
    exit 1
fi
echo "   Saved the encryption key to $KEY_FILE"

echo
echo "   Creating secrets in namespace $NAMESPACE..."

# Each Secret is written by its own API call, so a failure part way leaves the
# earlier ones written. Say which, and whether the key file matches the cluster.
WRITTEN_SECRETS=()
report_failed_write() {
    local failed="$1"

    echo
    echo "❌ Cannot write $failed in namespace $NAMESPACE"
    if [ ${#WRITTEN_SECRETS[@]} -gt 0 ]; then
        echo "   Already written: ${WRITTEN_SECRETS[*]}"
    else
        echo "   No Secrets were changed."
    fi
    if [[ " ${WRITTEN_SECRETS[*]} " == *" n8n-core-secrets "* ]]; then
        echo "   n8n-core-secrets holds the encryption key saved in $KEY_FILE"
    else
        echo "   n8n-core-secrets was not changed, so n8n does not use the key in $KEY_FILE"
    fi
    exit 1
}

# Create core secrets
echo "Creating n8n-core-secrets..."
apply_secret n8n-core-secrets \
    --from-file=N8N_ENCRYPTION_KEY=<(printf '%s' "$N8N_ENCRYPTION_KEY") \
    --from-file=N8N_RUNNERS_AUTH_TOKEN=<(printf '%s' "$N8N_RUNNERS_AUTH_TOKEN") \
    || report_failed_write n8n-core-secrets
WRITTEN_SECRETS+=(n8n-core-secrets)

# Create database secret
echo "Creating n8n-db-secret..."
apply_secret n8n-db-secret \
    --from-file=password=<(printf '%s' "$DB_PASSWORD") \
    || report_failed_write n8n-db-secret
WRITTEN_SECRETS+=(n8n-db-secret)

# Create S3 secret if requested
if [ "$CREATE_S3_SECRET" = true ]; then
    echo "Creating s3-credentials..."
    apply_secret s3-credentials \
        --from-file=secret-access-key=<(printf '%s' "$AWS_SECRET_ACCESS_KEY") \
        || report_failed_write s3-credentials
    WRITTEN_SECRETS+=(s3-credentials)
fi

echo
echo "   Secrets created successfully!"
echo

# Show what was created
echo "  Created secrets:"
kubectl get secrets -n "$NAMESPACE" "${SECRETS[@]}" 2>/dev/null || true

if [ ${#EXISTING_SECRETS[@]} -gt 0 ]; then
    echo
    echo "  Restart n8n so every container reads the new values:"
    echo "  kubectl rollout restart deployment -n $NAMESPACE -l app.kubernetes.io/name=n8n"
fi

echo
echo "  Next steps:"
echo "  1. Choose a values file from the examples/ directory"
echo "  2. Customize it for your environment"
echo "  3. Deploy with: helm install n8n ./charts/n8n --namespace $NAMESPACE -f your-values.yaml"
echo

echo "   IMPORTANT: Save your encryption key!"
echo "   Your encryption key has been saved to: $KEY_FILE"
echo "   Keep this file safe - you'll need it if you reinstall n8n"

echo
echo "   Security reminder:"
echo "   • Keep your encryption key safe and backed up"
echo "   • Don't commit secrets to version control"
echo "   • Consider using external secret management in production"
echo "   • Rotate secrets regularly"
