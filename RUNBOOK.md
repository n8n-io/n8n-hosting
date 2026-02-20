# RUNBOOK — Exact Commands

## First-time Setup

```bash
# 1. Clone / init repo
cd /path/to/project-root
git init
git remote add origin https://github.com/<org>/<repo>.git
git checkout -b main

# 2. Fill in secrets
nano infra/.env.local

# 3. Import your GPG public key into the local keyring
#    (util.sh does this automatically, but you can also do it manually)
gpg --import your-public-key.asc

# 4. Make scripts executable
chmod +x scripts/*.sh

# 5. Start services
docker compose -f infra/docker-compose.yml --env-file infra/.env.local up -d

# 6. Verify n8n is up
curl -s http://localhost:5678/healthz
```

---

## Daily Operations

### Start stack
```bash
docker compose -f infra/docker-compose.yml --env-file infra/.env.local up -d
```

### Stop stack
```bash
docker compose -f infra/docker-compose.yml down
```

### View logs
```bash
docker compose -f infra/docker-compose.yml logs -f
```

---

## Backup

### Manual backup (now)
```bash
./scripts/backup.sh
```

### Verify latest backup
```bash
DATE=$(date +%Y-%m-%d)
cat backups/daily/$DATE/meta.json | jq .
(cd backups/daily/$DATE && sha256sum -c checksums.txt)
```

### Schedule via cron
```bash
crontab -e
# Add:
# 0 0 * * * /bin/bash /ABSOLUTE/PATH/scripts/backup.sh >> /ABSOLUTE/PATH/backup.log 2>&1
```

---

## Restore

```bash
# List available backups
ls backups/daily/

# Restore a specific date
./scripts/restore.sh 2026-02-20
```

> Restore drops the current Postgres schema, re-imports the dump, extracts workflow files, and restarts containers.

---

## Guarded Cleanup

```bash
# Step 1 – dry run: shows token and opens GitHub Issue
./scripts/cleanup.sh

# Step 2 – actual cleanup (replace token with the one printed above)
./scripts/cleanup.sh DELETE_PROJECT_20260220
```

---

## Troubleshooting

### n8n cannot connect to Postgres
```bash
docker exec -it n8n_postgres pg_isready -U $POSTGRES_USER
docker compose -f infra/docker-compose.yml logs postgres
```

### GPG key not trusted
```bash
gpg --edit-key <key-fingerprint>
# type: trust → 5 (ultimate) → quit
```

### Backup push fails (auth error)
- Verify `GITHUB_PAT` in `infra/.env.local` has `repo` scope.
- Check `GITHUB_REPO` format is `org/repo` (no leading slash).

### Reset containers (keep data)
```bash
docker compose -f infra/docker-compose.yml restart
```

### Full reset (data preserved via backup)
```bash
./scripts/backup.sh                         # create snapshot
docker compose -f infra/docker-compose.yml down -v   # remove volumes
docker compose -f infra/docker-compose.yml up -d
./scripts/restore.sh $(date +%Y-%m-%d)     # restore from today's snapshot
```

---

## Environment Variables Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `POSTGRES_USER` | ✅ | Postgres superuser |
| `POSTGRES_PASSWORD` | ✅ | Postgres password |
| `POSTGRES_DB` | ✅ | Database name (default: `n8n`) |
| `N8N_ENCRYPTION_KEY` | ✅ | 32+ char random key for n8n credentials |
| `TZ` | ✅ | Timezone (e.g. `Asia/Riyadh`) |
| `GITHUB_REPO` | ✅ | `org/repo` for backup storage |
| `GITHUB_PAT` | ✅ | Personal Access Token (`repo` scope) |
| `GIT_AUTHOR_NAME` | optional | Git commit author name |
| `GIT_AUTHOR_EMAIL` | optional | Git commit author email |
| `GIT_BRANCH` | optional | Branch to push to (default: `main`) |
| `GPG_PUBLIC_KEY_ASCII` | ✅ | ASCII-armoured GPG public key |
| `GPG_RECIPIENT` | ✅ | GPG key identifier (email or fingerprint) |
| `TELEGRAM_BOT_TOKEN` | optional | Telegram Bot API token |
| `TELEGRAM_CHAT_ID` | optional | Channel/group/user chat ID |

---

## Telegram Integration

### 1. Create a bot

1. Open Telegram → search **@BotFather**
2. Send `/newbot` → choose a name → copy the **token**
3. Add the bot to your group/channel as **Admin**

### 2. Get the chat_id

```bash
# Replace TOKEN with your bot token
curl "https://api.telegram.org/bot<TOKEN>/getUpdates"
# Send any message to your group first, then look for "chat":{"id":-100xxxxxx}
```

### 3. Set variables in infra/.env.local

```dotenv
TELEGRAM_BOT_TOKEN=123456789:AAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TELEGRAM_CHAT_ID=-100xxxxxxxxxx
```

### 4. Test manually

```bash
source infra/.env.local
curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  -d parse_mode="Markdown" \
  -d text="*Test* from n8n-hosting ✅"
```

### What triggers Telegram messages

| Event | Message |
|-------|---------|
| Daily backup success | `💾 Backup ✅ YYYY-MM-DD` with time & path |
| Cleanup requested | `⚠️ CLEANUP REQUEST` with required token |
| Cleanup completed | `🗑️ Cleanup DONE` with date |

---

## n8n — How to Use

### Open the editor

```
http://localhost:5678
```

### Key concepts

| Term | Description |
|------|-------------|
| **Workflow** | A chain of nodes = automation pipeline |
| **Trigger node** | What starts the workflow (Cron, Webhook, etc.) |
| **Action node** | What the workflow does (HTTP, email, code, etc.) |
| **Credential** | Saved API key/token shared across workflows |

### Recommended workflows for this project

#### A) Daily backup via n8n Cron (alternative to system cron)

1. Create workflow → add **Schedule Trigger** node
   - Mode: `Cron`
   - Expression: `0 0 * * *` (midnight)
2. Add **Execute Command** node
   - Command: `/bin/bash /absolute/path/scripts/backup.sh`
3. Add **Telegram** node (n8n has a built-in node)
   - Operation: `Send Message`
   - Connect your Telegram credential
   - Message: `Backup done: {{ $now.toISO() }}`

#### B) Webhook → trigger backup on demand

1. Add **Webhook** trigger → copy the URL
2. Chain → **Execute Command** → `backup.sh`
3. Call from anywhere:
   ```bash
   curl -X POST http://localhost:5678/webhook/backup-now
   ```

#### C) Monitor n8n health and alert on Telegram

1. **Schedule Trigger** every 5 min
2. **HTTP Request** → `http://localhost:5678/healthz`
3. **IF** node → if response ≠ `ok` → **Telegram** alert

### Import/Export workflows

```bash
# Export all workflows to n8n-flows/
docker exec n8n n8n export:workflow --all --output=/home/node/.n8n/exported-flows/

# Import from a JSON file
docker exec n8n n8n import:workflow --input=/home/node/.n8n/exported-flows/workflow.json
```

---

## PDF Automation — Best Solutions

### Option 1: n8n built-in (recommended first choice)

n8n has no native PDF-fill node, but you chain nodes:

```
PDF template (base64) → Code node (pdf-lib) → Write Binary File → done
```

Install `pdf-lib` in the n8n container:
```bash
docker exec -u root n8n npm install -g pdf-lib
```

**n8n Code node example (fill a PDF form):**
```javascript
const { PDFDocument } = require('pdf-lib');
const fs = require('fs');

// Load template from filesystem or previous node output
const pdfBytes = Buffer.from($input.item.binary.data.data, 'base64');
const pdfDoc = await PDFDocument.load(pdfBytes);
const form = pdfDoc.getForm();

// Fill fields by name (must match the PDF form field names)
form.getTextField('FullName').setText($json.full_name);
form.getTextField('Date').setText($json.date);
form.getTextField('Amount').setText(String($json.amount));

// Flatten (locks the form)
form.flatten();

const filledBytes = await pdfDoc.save();
return [{ binary: { data: { data: Buffer.from(filledBytes).toString('base64'), mimeType: 'application/pdf' } } }];
```

---

### Option 2: Python `pypdf` / `reportlab` via Execute Command node

```bash
pip install pypdf reportlab
```

```python
# fill_pdf.py  – called from n8n Execute Command node
import sys, json
from pypdf import PdfReader, PdfWriter

data = json.loads(sys.argv[1])        # pass JSON from n8n
reader = PdfReader("template.pdf")
writer = PdfWriter()
writer.append(reader)
writer.update_page_form_field_values(
    writer.pages[0],
    {"FullName": data["full_name"], "Date": data["date"]}
)
with open("output.pdf", "wb") as f:
    writer.write(f)
```

n8n Execute Command node:
```bash
python3 /scripts/fill_pdf.py '{{ JSON.stringify($json) }}'
```

---

### Option 3: LibreOffice headless (best for complex templates)

```bash
# Convert DOCX template → filled DOCX → PDF
sudo apt-get install -y libreoffice
libreoffice --headless --convert-to pdf filled.docx
```

Use with n8n **Execute Command** node, passing variables via `sed` or a Python pre-processor.

---

### Option 4: Gotenberg (Docker micro-service — most powerful)

Add to `infra/docker-compose.yml`:

```yaml
  gotenberg:
    image: gotenberg/gotenberg:8
    container_name: gotenberg
    restart: always
    networks: [net]
    # No port published externally
```

Then from n8n **HTTP Request** node:

```
POST http://gotenberg:3000/forms/libreoffice/convert/office
Body: multipart/form-data
  files: your filled DOCX/ODT
```

Returns a ready PDF — no coding needed.

---

### Comparison

| Solution | Complexity | Best for |
|----------|-----------|---------|
| `pdf-lib` in n8n Code node | Low | Simple fillable PDF forms |
| Python `pypdf` | Medium | Existing PDF with form fields |
| LibreOffice headless | Medium | Complex DOCX → PDF |
| **Gotenberg** (Docker) | Low (API) | **Production, any format** |

> **Recommended:** Gotenberg for reliability + n8n HTTP Request node for zero-code integration.
