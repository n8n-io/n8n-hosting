#!/bin/bash
#
# Deploy Workflows to n8n Instance
#
# Usage:
#   ./deploy-workflow.sh [workflow-name]
#
# Environment variables required:
#   N8N_URL - URL of your n8n instance (e.g., https://n8n.example.com)
#   N8N_API_KEY - API key for n8n authentication
#
# Examples:
#   export N8N_URL="https://n8n.example.com"
#   export N8N_API_KEY="your_api_key"
#   ./deploy-workflow.sh                          # Deploy all workflows
#   ./deploy-workflow.sh palmaura-fal-image-generation  # Deploy specific workflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOWS_DIR="${SCRIPT_DIR}/../workflows"
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

# Function to deploy a single workflow
deploy_workflow() {
  local workflow_file="$1"
  local workflow_name=$(basename "$workflow_file" .json)

  echo -e "${YELLOW}Deploying: ${workflow_name}${NC}"

  # Check if file exists
  if [ ! -f "$workflow_file" ]; then
    echo -e "${RED}ERROR: Workflow file not found: ${workflow_file}${NC}"
    return 1
  fi

  # Deploy to n8n using API
  response=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "@${workflow_file}" \
    "${N8N_URL}/api/v1/workflows" 2>&1)

  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
    echo -e "${GREEN}✓ Successfully deployed: ${workflow_name}${NC}"

    # Extract workflow ID if available
    workflow_id=$(echo "$body" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$workflow_id" ]; then
      echo -e "${BLUE}  Workflow ID: ${workflow_id}${NC}"
    fi

    return 0
  else
    echo -e "${RED}✗ Failed to deploy: ${workflow_name} (HTTP ${http_code})${NC}"
    echo -e "${RED}Response: ${body}${NC}"
    return 1
  fi
}

# Main execution
echo "================================================"
echo "Cyclone-S5 Workflow Deployment"
echo "================================================"
echo "Target: ${N8N_URL}"
echo ""

# Check if workflows directory exists
if [ ! -d "$WORKFLOWS_DIR" ]; then
  echo -e "${RED}ERROR: Workflows directory not found: ${WORKFLOWS_DIR}${NC}"
  exit 1
fi

# Deploy specific workflow or all workflows
if [ -n "$1" ]; then
  # Deploy specific workflow
  workflow_path="${WORKFLOWS_DIR}/$1"

  # Add .json extension if not present
  if [[ "$1" != *.json ]]; then
    workflow_path="${workflow_path}.json"
  fi

  if [ -f "$workflow_path" ]; then
    deploy_workflow "$workflow_path"
  else
    echo -e "${RED}ERROR: Workflow not found: $1${NC}"
    echo ""
    echo "Available workflows:"
    ls -1 "${WORKFLOWS_DIR}"/*.json 2>/dev/null | xargs -n1 basename | sed 's/\.json$//' || echo "  (none found)"
    exit 1
  fi
else
  # Deploy all workflows
  echo "Deploying all workflows from: ${WORKFLOWS_DIR}"
  echo ""

  workflow_count=0
  success_count=0
  fail_count=0

  # Find all JSON files except README
  for workflow_file in "${WORKFLOWS_DIR}"/*.json; do
    # Skip if no files found
    if [ ! -f "$workflow_file" ]; then
      echo -e "${YELLOW}No workflow files found in ${WORKFLOWS_DIR}${NC}"
      break
    fi

    # Skip README and backup files
    filename=$(basename "$workflow_file")
    if [[ "$filename" == "README.json" ]] || [[ "$filename" == *"backup"* ]]; then
      continue
    fi

    workflow_count=$((workflow_count + 1))

    if deploy_workflow "$workflow_file"; then
      success_count=$((success_count + 1))
    else
      fail_count=$((fail_count + 1))
    fi

    echo "" # Blank line between workflows
  done

  # Summary
  echo "================================================"
  echo "Deployment Summary"
  echo "================================================"
  echo "Total workflows: $workflow_count"
  echo -e "${GREEN}Successful: $success_count${NC}"
  if [ $fail_count -gt 0 ]; then
    echo -e "${RED}Failed: $fail_count${NC}"
  else
    echo -e "Failed: $fail_count"
  fi
fi

echo ""
echo -e "${GREEN}Deployment complete!${NC}"
