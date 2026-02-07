#!/bin/bash
#
# Sync .env.example to Deployment Folders
#
# Copies the centralized config/.env.example to all deployment directories
# Ensures all deployment configurations have the latest environment template
#
# Usage:
#   ./sync-env.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ENV="${SCRIPT_DIR}/../config/.env.example"
DEPLOYMENT_DIR="${SCRIPT_DIR}/../deployment"

echo "================================================"
echo "Sync .env.example to Deployment Folders"
echo "================================================"
echo "Source: ${SOURCE_ENV}"
echo ""

# Check if source file exists
if [ ! -f "$SOURCE_ENV" ]; then
  echo -e "${RED}ERROR: Source .env.example not found at ${SOURCE_ENV}${NC}"
  exit 1
fi

# Deployment directories to sync
DEPLOY_TARGETS=(
  "docker-caddy"
  "docker-compose/withPostgres"
  "docker-compose/withPostgresAndWorker"
  "docker-compose/subfolderWithSSL"
)

sync_count=0
skip_count=0

# Copy to each deployment folder
for target in "${DEPLOY_TARGETS[@]}"; do
  target_path="${DEPLOYMENT_DIR}/${target}/.env.example"
  target_dir=$(dirname "$target_path")

  if [ -d "$target_dir" ]; then
    cp "$SOURCE_ENV" "$target_path"
    echo -e "${GREEN}✓ Synced to: ${target}/.env.example${NC}"
    sync_count=$((sync_count + 1))
  else
    echo -e "${YELLOW}⚠ Skipped (directory not found): ${target}${NC}"
    skip_count=$((skip_count + 1))
  fi
done

echo ""
echo "================================================"
echo "Sync Summary"
echo "================================================"
echo -e "${GREEN}Synced: $sync_count${NC}"
if [ $skip_count -gt 0 ]; then
  echo -e "${YELLOW}Skipped: $skip_count${NC}"
fi
echo ""
echo -e "${GREEN}Sync complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Navigate to each deployment directory"
echo "  2. Copy .env.example to .env: cp .env.example .env"
echo "  3. Edit .env with your actual credentials"
