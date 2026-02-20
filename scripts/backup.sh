#!/usr/bin/env bash
# backup.sh – create an encrypted daily rollback point and push to GitHub
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/util.sh"

ensure_tools
ensure_containers
import_gpg_pubkey
git_setup

DATE="$(today)"
STAMP="$(timestamp)"
OUT_DIR="$ROOT_DIR/backups/daily/$DATE"
STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT

mkdir -p "$OUT_DIR"

echo "[backup] Starting backup for $DATE …"

# ── 1) Postgres dump ──────────────────────────────────────────────────────────
# NOTE: No -t flag – TTY allocation corrupts binary pg_dump output
echo "[backup] Dumping Postgres …"
docker exec n8n_postgres \
  pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$STAGE_DIR/postgres.dump"

# Quick sanity check – a valid dump starts with "--"
head -c 2 "$STAGE_DIR/postgres.dump" | grep -q '^--' || {
  echo "[ERROR] Postgres dump appears corrupted or empty."; exit 1;
}

# ── 2) n8n workflows ─────────────────────────────────────────────────────────
echo "[backup] Exporting n8n workflows …"
if [ -d "$ROOT_DIR/data/n8n/workflows" ]; then
  tar -C "$ROOT_DIR/data/n8n/workflows" -cf "$STAGE_DIR/n8n-flows.tar" .
else
  # Create a valid empty tar archive (portable across GNU/BSD tar)
  touch "$STAGE_DIR/.empty_placeholder"
  tar -cf "$STAGE_DIR/n8n-flows.tar" -C "$STAGE_DIR" .empty_placeholder
  rm -f "$STAGE_DIR/.empty_placeholder"
fi

# ── 3) OpenClaw state ─────────────────────────────────────────────────────────
echo "[backup] Collecting OpenClaw state …"
if [ -f "$ROOT_DIR/data/openclaw/state.json" ]; then
  cp "$ROOT_DIR/data/openclaw/state.json" "$STAGE_DIR/openclaw-state.json"
else
  echo "{}" > "$STAGE_DIR/openclaw-state.json"
fi

# ── 4) Encrypt with GPG ───────────────────────────────────────────────────────
echo "[backup] Encrypting artifacts …"
GPG_RECIPIENT="${GPG_RECIPIENT:-backup}"
for f in postgres.dump n8n-flows.tar openclaw-state.json; do
  gpg --yes --batch -r "$GPG_RECIPIENT" \
      -o "$STAGE_DIR/${f}.gpg" -e "$STAGE_DIR/$f"
done

# ── 5) Checksums + meta.json ──────────────────────────────────────────────────
echo "[backup] Computing checksums …"
(
  cd "$STAGE_DIR"
  sha256sum postgres.dump.gpg n8n-flows.tar.gpg openclaw-state.json.gpg \
    > checksums.txt

  N8N_VER="$(docker exec n8n \
    node -e "console.log(require('/usr/local/lib/node_modules/n8n/package.json').version)" \
    2>/dev/null || echo 'unknown')"
  PG_VER="$(docker exec n8n_postgres psql --version 2>/dev/null | awk '{print $3}' \
    || echo 'unknown')"

  jq -n \
    --arg  date   "$DATE" \
    --arg  time   "$STAMP" \
    --arg  host   "localhost" \
    --arg  n8n    "$N8N_VER" \
    --arg  pg     "$PG_VER" \
    --argjson files '["postgres.dump.gpg","n8n-flows.tar.gpg","openclaw-state.json.gpg"]' \
    '{date:$date,time:$time,host:$host,n8n_version:$n8n,postgres_version:$pg,files:$files}' \
    > meta.json
)

# ── 6) Stage into repo path ───────────────────────────────────────────────────
cp "$STAGE_DIR"/{postgres.dump.gpg,n8n-flows.tar.gpg,openclaw-state.json.gpg,meta.json,checksums.txt} \
   "$OUT_DIR/"

# ── 7) Commit + push (using HTTPS PAT, no SSH needed) ────────────────────────
echo "[backup] Committing to GitHub …"
(
  cd "$ROOT_DIR"
  git add "backups/daily/$DATE"
  git commit -m "chore(backup): daily rollback point $DATE"
  git push \
    "https://${GIT_AUTHOR_NAME:-automation-bot}:${GITHUB_PAT}@github.com/${GITHUB_REPO}.git" \
    "${GIT_BRANCH:-main}"
)

# ── 8) Notifications ─────────────────────────────────────────────────────────────
echo "[backup] Notifying GitHub …"
"$ROOT_DIR/scripts/notify_github.sh" notify_backup "$DATE" "✅ success" \
  "backups/daily/$DATE/meta.json" \
  || echo "[WARN] GitHub notification failed (backup itself succeeded)."

echo "[backup] Notifying Telegram …"
notify_telegram \
  "💾 Backup ✅ $DATE" \
  "$(printf 'Status: success\nTime: %s\nFiles: backups/daily/%s/' "$STAMP" "$DATE")" \
  || true

echo "[backup] ✅ Done – rollback point created for $DATE"
echo "[backup] Files: $OUT_DIR"
