#!/usr/bin/env bash
# cleanup.sh – guarded cleanup routine
#
# STEP 1 (no args):  show the required confirmation token, open a GitHub Issue.
# STEP 2 (with token): create final backup, stop containers, delete data safely.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/util.sh"

CONFIRM="${1:-}"
REQUIRED="DELETE_PROJECT_$(token)"

# ─── Step 1: no confirmation token supplied ──────────────────────────────────
if [ -z "$CONFIRM" ]; then
  cat <<EOF
╔══════════════════════════════════════════════════════════════════╗
║               GUARDED CLEANUP – READ CAREFULLY                  ║
╠══════════════════════════════════════════════════════════════════╣
║  This will:                                                      ║
║    1. Create a final encrypted backup snapshot.                  ║
║    2. Stop all Docker containers.                                ║
║    3. Delete data/ directories ONLY inside the project root.     ║
║                                                                  ║
║  Nothing outside $ROOT_DIR is touched.                           ║
╚══════════════════════════════════════════════════════════════════╝

To proceed, re-run with the exact token below:

  ./scripts/cleanup.sh ${REQUIRED}

A GitHub Issue has been opened requesting human confirmation.
EOF
  "$ROOT_DIR/scripts/notify_github.sh" notify_cleanup_request "$REQUIRED" || true
  notify_telegram \
    "⚠️ CLEANUP REQUEST" \
    "$(printf 'Token required:\n`%s`\n\nRun:\n./scripts/cleanup.sh %s' "$REQUIRED" "$REQUIRED")" \
    || true
  exit 0
fi

# ─── Step 2: validate confirmation token ────────────────────────────────────
if [ "$CONFIRM" != "$REQUIRED" ]; then
  echo "ERROR: Confirmation token mismatch."
  echo "  Expected : $REQUIRED"
  echo "  Received : $CONFIRM"
  exit 1
fi

# ─── Final snapshot backup ───────────────────────────────────────────────────
echo "[cleanup] Creating final snapshot backup before deletion …"
"$ROOT_DIR/scripts/backup.sh" || {
  echo "ERROR: Backup failed. Aborting cleanup to protect your data."
  exit 1
}

# ─── Stop containers ─────────────────────────────────────────────────────────
echo "[cleanup] Stopping containers …"
docker compose -f "$ROOT_DIR/infra/docker-compose.yml" down || true

# ─── Safely delete project data ──────────────────────────────────────────────
TARGETS=(
  "$ROOT_DIR/data/postgres"
  "$ROOT_DIR/data/n8n"
  "$ROOT_DIR/data/openclaw"
)

for p in "${TARGETS[@]}"; do
  # Safety guard: only delete paths strictly under ROOT_DIR
  if [[ "$p" == "$ROOT_DIR/"* ]] && [ -e "$p" ]; then
    rm -rf "$p"
    echo "[cleanup] Deleted: $p"
  else
    echo "[cleanup] Skipped (unsafe or non-existent path): $p"
  fi
done

notify_telegram \
  "🗑️ Cleanup DONE" \
  "$(printf 'All data volumes deleted safely.\nFinal backup created first.\nDate: %s' "$(today)")" \
  || true

echo "[cleanup] Cleanup completed safely. All data backed up before deletion."

