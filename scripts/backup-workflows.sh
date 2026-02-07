#!/bin/bash
#
# Backup Workflows from n8n Instance
#
# Usage:
#   ./backup-workflows.sh
#
# Environment variables required:
#   N8N_URL - URL of your n8n instance
#   N8N_API_KEY - API key for n8n authentication
#
# Example:
#   export N8N_URL="https://n8n.example.com"
#   export N8N_API_KEY="your_api_key"
#   ./backup-workflows.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOWS_DIR="${SCRIPT_DIR}/../workflows"
BACKUP_DIR="${WORKFLOWS_DIR}/backups"
N8N_URL="${N8N_URL:-}"
N8N_API_KEY="${N8N_API_KEY:-}"

# Check if required environment variables are set
if [ -z "$N8N_URL" ]; then
  echo -e "${RED}ERROR: N8N_URL environment variable is not set${NC}"
  echo "Please set it with: export N8N_URL=\"https://your-n8n-instance.com\""
  exit 1
fi

if [ -z "$N8N_API_KEY" ]; then
  echo -e "${RED}ERROR: N8N_API_KEY environment variable is not set${NC}"
  echo "Please set it with: export N8N_API_KEY=\"your_api_key\""
  exit 1
fi

# Create directories if they don't exist
mkdir -p "$WORKFLOWS_DIR"
mkdir -p "$BACKUP_DIR"

# Check if jq is available (optional, for pretty printing)
if command -v jq &> /dev/null; then
  HAS_JQ=true
else
  HAS_JQ=false
  echo -e "${YELLOW}Note: jq not installed. Workflows will be saved without pretty-printing.${NC}"
  echo "Install jq for better formatting: sudo apt-get install jq"
  echo ""
fi

echo "================================================"
echo "Cyclone-S5 Workflow Backup"
echo "================================================"
echo "Source: ${N8N_URL}"
echo "Target: ${WORKFLOWS_DIR}"
echo "Backup: ${BACKUP_DIR}"
echo ""

# Fetch all workflows from n8n
echo -e "${YELLOW}Fetching workflows from n8n...${NC}"
workflows=$(curl -s \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  "${N8N_URL}/api/v1/workflows")

# Check if request was successful
if [ $? -ne 0 ]; then
  echo -e "${RED}ERROR: Failed to fetch workflows from n8n${NC}"
  exit 1
fi

# Check if workflows data is valid JSON
if ! echo "$workflows" | jq . > /dev/null 2>&1; then
  echo -e "${RED}ERROR: Invalid response from n8n API${NC}"
  echo "Response: $workflows"
  exit 1
fi

# Count workflows
workflow_count=$(echo "$workflows" | jq '.data | length' 2>/dev/null || echo "0")

if [ "$workflow_count" -eq 0 ]; then
  echo -e "${YELLOW}No workflows found on n8n instance${NC}"
  exit 0
fi

echo -e "${BLUE}Found $workflow_count workflows${NC}"
echo ""

# Process each workflow
# Use a pre-parsed list to avoid subshell issues and catch jq failures
saved_count=0
error_count=0
timestamp=$(date +%Y%m%d_%H%M%S)

if ! workflows_list=$(echo "$workflows" | jq -c '.data[]' 2>/dev/null); then
  echo -e "${RED}ERROR: Failed to parse workflow data${NC}"
  exit 1
fi

while IFS= read -r workflow; do
  workflow_id=$(echo "$workflow" | jq -r '.id')
  workflow_name=$(echo "$workflow" | jq -r '.name')

  # Sanitize filename (replace spaces and special chars with dashes)
  safe_name=$(echo "$workflow_name" | tr ' ' '-' | tr -cd '[:alnum:]-_')

  # If safe_name is empty, use workflow ID
  if [ -z "$safe_name" ]; then
    safe_name="workflow-${workflow_id}"
  fi

  echo -e "${YELLOW}Backing up: ${workflow_name} (${workflow_id})${NC}"

  # Save to workflows directory
  save_success=true
  if [ "$HAS_JQ" = true ]; then
    if ! echo "$workflow" | jq '.' > "${WORKFLOWS_DIR}/${safe_name}.json"; then
      save_success=false
    fi
  else
    if ! echo "$workflow" > "${WORKFLOWS_DIR}/${safe_name}.json"; then
      save_success=false
    fi
  fi

  if [ "$save_success" = true ]; then
    # Also save timestamped backup
    if [ "$HAS_JQ" = true ]; then
      echo "$workflow" | jq '.' > "${BACKUP_DIR}/${safe_name}_${timestamp}.json"
    else
      echo "$workflow" > "${BACKUP_DIR}/${safe_name}_${timestamp}.json"
    fi

    echo -e "${GREEN}✓ Saved: ${safe_name}.json${NC}"
    saved_count=$((saved_count + 1))
  else
    echo -e "${RED}✗ Failed to save: ${safe_name}.json${NC}"
    error_count=$((error_count + 1))
  fi
done <<< "$workflows_list"

echo ""
echo "================================================"
echo "Backup Summary"
echo "================================================"
echo -e "${GREEN}Workflows backed up: $saved_count${NC}"
if [ $error_count -gt 0 ]; then
  echo -e "${RED}Failed to backup: $error_count${NC}"
fi
echo ""
echo "Main copies saved to: ${WORKFLOWS_DIR}"
echo "Timestamped backups saved to: ${BACKUP_DIR}"
echo ""

# Exit with error if any backups failed
if [ $error_count -gt 0 ]; then
  echo -e "${RED}Backup completed with errors!${NC}"
  exit 1
fi

echo -e "${GREEN}Backup complete!${NC}"
echo ""
echo "To deploy these workflows to another n8n instance:"
echo "  export N8N_URL=\"https://other-n8n-instance.com\""
echo "  export N8N_API_KEY=\"other_api_key\""
echo "  ./deploy-workflow.sh"
