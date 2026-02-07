# Cyclone-S5

**Production-ready n8n workflows for AI-powered ad creative generation at scale**

Automated image generation, prompt optimization, and workflow management for advertising campaigns using Airtable, fal.ai, and Bannerbear.

---

## 🚀 Quick Start

### 1. Configure Environment

```bash
# Copy the environment template
cp config/.env.example config/.env

# Edit .env with your credentials
# - Airtable Personal Access Token
# - fal.ai API Key
# - Bannerbear API Key
# - n8n URL and API Key (for deployment/backup)
```

### 2. Deploy Workflows to n8n

```bash
cd scripts

# Set environment variables
export N8N_URL="https://your-n8n-instance.com"
export N8N_API_KEY="your_api_key"

# Deploy all workflows
./deploy-workflow.sh

# Or deploy a specific workflow
./deploy-workflow.sh palmaura-fal-image-generation
```

### 3. Validate Configuration

```bash
# Run validation script
node scripts/validate-config.js
```

---

## 📁 Repository Structure

```
Cyclone-S5/
├── workflows/              # n8n workflow JSON files
│   ├── palmaura-fal-image-generation.json
│   ├── claude-n8n-http.json
│   └── README.md          # Workflow documentation
├── config/                # Configuration templates
│   ├── .env.example       # Environment variables
│   ├── airtable-schemas.json
│   ├── api-endpoints.json
│   └── prompt-templates.json
├── utils/n8n-helpers/     # Reusable helper functions
│   ├── airtable-ops.js    # Airtable CRUD operations
│   ├── image-generation.js
│   ├── prompt-builder.js
│   └── error-handler.js
├── schemas/               # TypeScript type definitions
├── scripts/               # Deployment & maintenance scripts
│   ├── deploy-workflow.sh
│   ├── backup-workflows.sh
│   ├── validate-config.js
│   └── sync-env.sh
├── deployment/            # Legacy n8n deployment configs
└── .github/workflows/     # Automated workflow backups
```

---

## ⚙️ Configuration

### Required API Keys

All configuration is centralized in [config/.env.example](config/.env.example):

- **Airtable**: Personal Access Token from [airtable.com/create/tokens](https://airtable.com/create/tokens)
- **fal.ai**: API key from [fal.ai/dashboard/keys](https://fal.ai/dashboard/keys)
- **Bannerbear**: API key from [app.bannerbear.com](https://app.bannerbear.com/account/settings)
- **OpenAI**: API key from [platform.openai.com/api-keys](https://platform.openai.com/api-keys) (optional)

### Airtable Setup

Your Airtable base should include these tables:

| Table | Purpose |
|-------|---------|
| **Ad Copy** | Ad concepts, prompts, and generation status |
| **Images** | Generated image metadata |
| **Actors** | Character descriptions for prompts |
| **Products** | Product information |
| **Scenes** | Scene/environment descriptions |

See [config/airtable-schemas.json](config/airtable-schemas.json) for field definitions.

---

## 🔄 Workflows

### PalmAura - Image Generation at Scale

**File**: [workflows/palmaura-fal-image-generation.json](workflows/palmaura-fal-image-generation.json)

Automated pipeline that:
1. Fetches ad copy records from Airtable
2. Validates and cleans image prompts
3. Generates images using fal.ai Flux Dev model
4. Handles retries and error logging
5. Updates Airtable with results

**Triggers**:
- **Schedule**: Hourly check for new records
- **Webhook**: `/webhook/palmaura-generate-images`

**Environment Variables Used**:
- `AIRTABLE_BASE_ID`, `AIRTABLE_PAT`
- `AIRTABLE_TABLE_AD_COPY`
- `FAL_API_KEY`

See [workflows/README.md](workflows/README.md) for detailed workflow documentation.

---

## 🛠️ Helper Scripts

### Airtable Operations

```javascript
// In n8n Code node
const { fetchRecord, updateRecord } = require('./utils/n8n-helpers/airtable-ops.js');

const record = fetchRecord('recXXXXXXXX', $env.AIRTABLE_TABLE_AD_COPY);
updateRecord('recXXXXXXXX', $env.AIRTABLE_TABLE_AD_COPY, {
  'Image Generated': true,
  'Image URL': imageUrl
});
```

### Image Generation

```javascript
const { generateImage, validatePrompt } = require('./utils/n8n-helpers/image-generation.js');

const result = generateImage(prompt, {
  image_size: 'landscape_16_9',
  num_inference_steps: 28
});
```

### Error Handling

```javascript
const { isRetryable, getRetryDelay } = require('./utils/n8n-helpers/error-handler.js');

if (isRetryable(response.statusCode)) {
  const delay = getRetryDelay(attemptNumber);
  await wait(delay);
  // Retry logic
}
```

---

## 📜 Scripts

### Deploy Workflows

```bash
# Deploy all workflows to n8n instance
export N8N_URL="https://your-n8n-instance.com"
export N8N_API_KEY="your_api_key"
./scripts/deploy-workflow.sh

# Deploy specific workflow
./scripts/deploy-workflow.sh palmaura-fal-image-generation
```

### Backup Workflows

```bash
# Backup workflows from n8n to git
export N8N_URL="https://your-n8n-instance.com"
export N8N_API_KEY="your_api_key"
./scripts/backup-workflows.sh
```

Backups are saved to:
- `workflows/` - Latest version
- `workflows/backups/` - Timestamped copies

### Validate Configuration

```bash
# Validate all configuration files
node scripts/validate-config.js
```

Checks:
- JSON syntax in all config files
- Required environment variables in .env.example
- Airtable schema completeness
- Workflow file validity

### Sync Environment Templates

```bash
# Sync .env.example to deployment folders
./scripts/sync-env.sh
```

---

## 🔐 Security

**Critical**: Never commit `.env` files to git!

The `.gitignore` is configured to prevent this, but always verify:

```bash
# Check what will be committed
git status

# Ensure .env files are not listed
```

### API Key Management

- Store API keys in `.env` files (local development)
- Use GitHub Secrets for CI/CD (production)
- Rotate keys regularly
- Use Personal Access Tokens (PAT) for Airtable, not API keys

---

## 🤖 Automated Backups

GitHub Actions automatically backs up workflows daily:

**Schedule**: 2 AM UTC daily
**Manual Trigger**: `Actions` → `Backup n8n Workflows` → `Run workflow`

**Setup**:
1. Add GitHub Secrets:
   - `N8N_URL`: Your n8n instance URL
   - `N8N_API_KEY`: Your n8n API key

2. The workflow will automatically:
   - Fetch all workflows from n8n
   - Save to `workflows/` directory
   - Create timestamped backups in `workflows/backups/`
   - Commit and push changes

---

## 📚 Documentation

- **[Workflows README](workflows/README.md)**: Detailed workflow documentation
- **[Deployment README](deployment/README.md)**: Legacy deployment configurations
- **[Config Schemas](config/)**: API endpoints, Airtable schemas, prompt templates
- **[TypeScript Schemas](schemas/)**: Type definitions for all data structures

---

## 🧪 Testing

### Test Configuration

```bash
node scripts/validate-config.js
```

### Test Deployment

```bash
export N8N_URL="https://test-n8n-instance.com"
export N8N_API_KEY="test_api_key"
./scripts/deploy-workflow.sh
```

### Test Workflows

1. Import workflow into n8n
2. Configure credentials
3. Use "Execute Workflow" with test data
4. Check execution logs for errors

---

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes**
4. **Test thoroughly**: Run `node scripts/validate-config.js`
5. **Commit your changes**: `git commit -m 'feat: add amazing feature'`
6. **Push to the branch**: `git push origin feature/amazing-feature`
7. **Open a Pull Request**

---

## 📝 License

This project uses configurations from [n8n-io/n8n-hosting](https://github.com/n8n-io/n8n-hosting) (Apache 2.0).

Custom workflows and utilities: Proprietary

---

## 🆘 Support

### Common Issues

**"Missing Airtable credentials"**
- Ensure `.env` file exists in `config/` directory
- Verify `AIRTABLE_PAT` and `AIRTABLE_BASE_ID` are set

**"Workflow deployment failed"**
- Check `N8N_URL` and `N8N_API_KEY` environment variables
- Verify n8n instance is accessible
- Check n8n API key has correct permissions

**"Image generation timeout"**
- fal.ai requests can take 30-120 seconds
- Increase timeout in workflow settings
- Check fal.ai API key and rate limits

### Getting Help

- Check the [workflows/README.md](workflows/README.md) for workflow-specific help
- Review logs in n8n UI: Executions → View Details
- Validate configuration: `node scripts/validate-config.js`

---

## 🙏 Acknowledgments

- [n8n](https://n8n.io/) - Workflow automation platform
- [fal.ai](https://fal.ai/) - AI image generation
- [Airtable](https://airtable.com/) - Database and workflow management
- [Bannerbear](https://www.bannerbear.com/) - Image overlay templates

---

**Built with ❤️ for AdScaler / PalmAura**
