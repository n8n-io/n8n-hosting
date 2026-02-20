#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/infra/.env.local"

if [ ! -f "$ENV_FILE" ]; then
  echo "[ERROR] Missing secrets file: $ENV_FILE"
  echo "        Copy infra/.env.local from the template and fill in all values."
  exit 1
fi

# Load env (safe: handles comments and blank lines)
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# ── git identity scoped to this repo (no global changes) ────────────────────
git_setup() {
  git -C "$ROOT_DIR" config user.name  "${GIT_AUTHOR_NAME:-automation-bot}"
  git -C "$ROOT_DIR" config user.email "${GIT_AUTHOR_EMAIL:-bot@users.noreply.github.com}"
}

# ── Verify all required CLI tools are present ───────────────────────────────
ensure_tools() {
  local missing=0
  for t in gpg jq sha256sum docker curl git; do
    command -v "$t" >/dev/null 2>&1 || { echo "[ERROR] Missing tool: $t"; missing=1; }
  done
  [ "$missing" -eq 0 ] || { echo "Install missing tools and retry."; exit 1; }
}

# ── Verify required containers are running ──────────────────────────────────
ensure_containers() {
  local containers=("n8n_postgres" "n8n")
  local missing=0
  for c in "${containers[@]}"; do
    if ! docker inspect --format '{{.State.Running}}' "$c" 2>/dev/null | grep -q true; then
      echo "[ERROR] Container not running: $c"
      echo "        Run: docker compose -f $ROOT_DIR/infra/docker-compose.yml --env-file $ROOT_DIR/infra/.env.local up -d"
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || exit 1
}

# ── Import GPG public key (handles literal \n in env var) ───────────────────
import_gpg_pubkey() {
  if [ -z "${GPG_PUBLIC_KEY_ASCII:-}" ]; then
    echo "[WARN] GPG_PUBLIC_KEY_ASCII is empty – skipping key import."
    return 0
  fi
  # printf '%b' converts literal \n sequences into real newlines
  printf '%b\n' "$GPG_PUBLIC_KEY_ASCII" | gpg --import --batch 2>&1 || true
}

# ── Telegram notification ────────────────────────────────────────────────
# Usage: notify_telegram "🌟 Title" "Body text here"
notify_telegram() {
  local title="$1" body="$2"
  # Skip silently if credentials are not configured
  if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
    echo "[WARN] Telegram not configured (TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID missing) – skipping."
    return 0
  fi
  local text
  text="$(printf '*%s*\n%s' "$title" "$body")"
  curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d parse_mode="Markdown" \
    --data-urlencode text="${text}" \
    >/dev/null \
    || echo "[WARN] Telegram send failed (network error?)"
}

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
today()     { date +"%Y-%m-%d"; }
token()     { date +"%Y%m%d"; }
