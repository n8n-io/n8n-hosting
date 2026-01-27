# n8n AI Operating Model Audit Platform

[![CI](https://github.com/Spenny24/n8n-hosting/actions/workflows/blank.yml/badge.svg)](https://github.com/Spenny24/n8n-hosting/actions/workflows/blank.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> Enterprise-grade platform for automating AI Operating Model audits using n8n workflows. Generates consultant-grade reports with financial analysis, ROI calculations, and implementation roadmaps.

## 🎯 Overview

This repository provides a complete infrastructure and workflow solution for running AI Operating Model audits at scale. Built on n8n, it combines data collection, AI analysis, and comprehensive report generation to deliver consulting-quality deliverables at a fraction of the cost.

### Key Features

- 🚀 **Multiple Deployment Options** - Docker Compose, Kubernetes, or Caddy reverse proxy
- 📊 **Pre-built Workflow Templates** - Production-ready audit workflows (Standard & Premium)
- 🔗 **Multi-source Integration** - Google Sheets, Airtable, Google Drive, Slack, Supabase
- 🤖 **AI-Powered Analysis** - GPT-4 driven report generation with cost optimization
- 💰 **Cost Efficient** - $0.006-$0.99 per audit vs $15K-$50K consulting fees
- ⚡ **Performance Optimized** - Parallel execution, 50% faster than sequential approaches
- 🛡️ **Production Ready** - Error handling, data validation, comprehensive logging

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Workflows](#-workflows)
- [Deployment Options](#-deployment-options)
- [Prerequisites](#-prerequisites)
- [Configuration](#-configuration)
- [Documentation](#-documentation)
- [Cost Analysis](#-cost-analysis)
- [Architecture](#-architecture)
- [Contributing](#-contributing)
- [License](#-license)

## 🚀 Quick Start

### 1. Choose Your Deployment

```bash
# Option 1: Docker Compose with PostgreSQL (Recommended)
cd docker-compose/withPostgres
cp .env.example .env
# Edit .env with your credentials
docker-compose up -d

# Option 2: Kubernetes
cd kubernetes
kubectl apply -f n8n-deployment.yaml

# Option 3: Caddy Reverse Proxy with SSL
cd docker-caddy
cp .env.example .env
# Edit .env with your domain
docker-compose up -d
```

### 2. Import Workflow

1. Access n8n at `http://localhost:5678` (or your configured domain)
2. Navigate to **Workflows** → **Add Workflow** → **Import from File**
3. Select one of the workflows from the `workflows/` directory:
   - `improved_ai_operating_model_workflow.json` (Standard - $0.21/audit)
   - `workflow_premium_google_sheets.json` (Premium - $0.99/audit)

### 3. Configure Credentials

Set up the following credentials in n8n:
- ✅ Google Drive OAuth2
- ✅ Google Sheets OAuth2
- ✅ Airtable API Token (optional, for Airtable version)
- ✅ OpenAI API Key
- ✅ Supabase API Key
- ✅ Slack OAuth2

### 4. Run Your First Audit

1. Click **Execute Workflow**
2. Execution completes in ~70 seconds
3. Check outputs:
   - Airtable/Google Sheets: Client record created
   - Google Drive: Report uploaded
   - Slack: Notification sent

📖 **Detailed Guide:** See [docs/QUICK_START.md](docs/QUICK_START.md) for step-by-step instructions.

## 📦 Workflows

### Available Workflows

| Workflow | Use Case | Model | Cost/Audit | Output |
|----------|----------|-------|------------|--------|
| **Standard** | Internal audits, testing | GPT-4o-mini | $0.006 | 1,500 words |
| **Improved V4** | Production audits | GPT-4o-mini | $0.21 | 3,000 words |
| **Premium Google Sheets** | Client deliverables | GPT-4o | $0.99 | 6,000-8,000 words |
| **Financial Deep-Dive** | CFO-grade analysis | GPT-4o | $1.20 | 8,000+ words |
| **Lead Generation** | Sales automation | Groq | $0.05 | Email campaigns |

### Workflow Comparison

**Standard vs Premium:**

| Feature | Standard | Premium |
|---------|----------|---------|
| Sections | 4 | 8 |
| Tables | 0-1 | 6+ detailed tables |
| Word Count | ~1,500 | 6,000-8,000 |
| Financial Analysis | Basic ROI | TCO, NPV, IRR, Cash Flow |
| Implementation Plan | High-level | 4-phase roadmap with deliverables |
| Risk Assessment | Mentioned | Risk matrix with mitigation strategies |

📚 **Full Catalog:** See [workflows/README.md](workflows/README.md)

## 🏗️ Deployment Options

### 1. Docker Compose with PostgreSQL (Recommended)

**Best for:** Production use, persistent data storage

```bash
cd docker-compose/withPostgres
docker-compose up -d
```

**Features:**
- PostgreSQL database for workflow persistence
- Volume mounting for data backup
- Health checks
- Auto-restart on failure

### 2. Docker Compose with Worker

**Best for:** High-volume workloads, parallel execution

```bash
cd docker-compose/withPostgresAndWorker
docker-compose up -d
```

**Features:**
- Separate worker container for job execution
- Horizontal scaling capability
- Load distribution

### 3. Kubernetes

**Best for:** Enterprise deployments, multi-tenant environments

```bash
cd kubernetes
kubectl apply -f n8n-deployment.yaml
```

**Features:**
- High availability
- Auto-scaling
- Resource management
- Service mesh integration

### 4. Caddy with SSL

**Best for:** Public-facing deployments with automatic SSL

```bash
cd docker-caddy
docker-compose up -d
```

**Features:**
- Automatic Let's Encrypt certificates
- Reverse proxy with HTTP/2
- Zero-config SSL/TLS

## ✅ Prerequisites

### Required

- **Docker** 20.10+ and **Docker Compose** 2.0+
- **n8n** v1.0+ (included in Docker images)
- **OpenAI API Key** with billing enabled
- **Google Cloud Project** with APIs enabled:
  - Google Drive API
  - Google Sheets API
- **4GB RAM minimum** (8GB recommended for Premium workflows)

### Optional

- **Airtable Account** (for Airtable-based workflows)
- **Supabase Project** (for pattern learning/storage)
- **Slack Workspace** (for notifications)
- **Kubernetes Cluster** (for K8s deployment)

## ⚙️ Configuration

### Environment Variables

Each deployment option uses a `.env` file for configuration:

```bash
# Copy example file
cp .env.example .env

# Edit with your values
nano .env
```

**Key Variables:**

```bash
# Database
POSTGRES_USER=your_user
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DB=n8n

# n8n
ENCRYPTION_KEY=your_encryption_key  # Generate: openssl rand -base64 32

# Domain (for SSL deployments)
DOMAIN_NAME=n8n.yourdomain.com
SSL_EMAIL=admin@yourdomain.com

# Timezone
GENERIC_TIMEZONE=America/New_York
```

### Google Sheets Setup

1. Create a Google Sheets document with these sheets:
   - `RACI_Matrix` - Process ownership data
   - `Tool_Inventory` - Technology stack
   - `KPI_Snapshot` - Performance metrics
   - `Client_Models` - Results storage

2. Update sheet IDs in the "Set Client Config" node

📖 **Detailed Guide:** See [docs/GOOGLE_SHEETS_SETUP_GUIDE.md](docs/GOOGLE_SHEETS_SETUP_GUIDE.md)

## 📚 Documentation

### Getting Started
- [Quick Start Guide](docs/QUICK_START.md) - 5-minute setup
- [Google Sheets Setup](docs/GOOGLE_SHEETS_SETUP_GUIDE.md) - Data source configuration
- [Workflow Improvements Guide](docs/WORKFLOW_IMPROVEMENTS_GUIDE.md) - Optimization tips

### Technical Deep-Dives
- [Architecture Comparison](docs/ARCHITECTURE_COMPARISON.md) - V3 vs V4 design
- [Cost Analysis](docs/COST_ANALYSIS.md) - Detailed cost breakdown
- [Premium Workflow README](docs/PREMIUM_WORKFLOW_README.md) - Enterprise features
- [Premium Report Specification](docs/PREMIUM_REPORT_SPECIFICATION.md) - Output format details

### Enhancement Roadmaps
- [Consultant Grade Enhancements](docs/CONSULTANT_GRADE_ENHANCEMENTS.md) - Future improvements
- [Google Drive Trigger Spec](docs/GOOGLE_DRIVE_TRIGGER_SPEC.md) - Automation plans
- [Session Summary](docs/SESSION_SUMMARY.md) - Development history

### Code Utilities
- [Data Cleaner V3](scripts/DATA_CLEANER_V3_CODE.js) - Data normalization code
- [Environment Guard Fix](scripts/ENVIRONMENT_GUARD_FIX.js) - n8n compatibility fix
- [Update Premium Prompts](scripts/update_premium_prompts.py) - Prompt management script

## 💰 Cost Analysis

### Per-Audit Costs

| Workflow Version | Input Tokens | Output Tokens | Cost | Value |
|------------------|--------------|---------------|------|-------|
| Standard | 8,500 | 2,000 | $0.006 | $5K-$10K |
| Improved V4 | 18,500 | 4,000 | $0.21 | $10K-$20K |
| Premium | 35,000 | 12,000 | $0.99 | $15K-$50K |
| Financial Deep-Dive | 45,000 | 15,000 | $1.20 | $25K-$75K |

### Monthly Costs (10 Audits)

- **Standard:** $0.06/month
- **Improved V4:** $2.10/month
- **Premium:** $9.90/month
- **Mix (7 Standard + 3 Premium):** $3.00/month

**ROI:** 99.998% cost reduction vs traditional consulting

📊 **Detailed Breakdown:** See [docs/COST_ANALYSIS.md](docs/COST_ANALYSIS.md)

## 🏛️ Architecture

### Workflow Architecture (V4)

```
┌─────────────────────────────────────────────┐
│ Trigger Layer + Utilities                   │
│ Environment validation, shared functions    │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│ Data Collection (Parallel)                  │
│ Google Drive, Sheets, Airtable             │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│ Analysis Layer (Parallel + Validation)      │
│ Data cleaning, inefficiency analysis        │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│ Design Layer                                │
│ AI architecture, ROI simulation             │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│ Report Generation (Parallel) ⚡             │
│ 4 GPT-4 calls in parallel                  │
│ 69% faster than sequential                 │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│ Output & Learning Layer                     │
│ Storage, notifications, pattern learning    │
└─────────────────────────────────────────────┘
```

### Key Improvements (V3 → V4)

- ⚡ **50% faster execution** (131s → 65s)
- 💰 **40% cost reduction** ($0.35 → $0.21)
- 🧩 **34% fewer nodes** (65 → 43)
- 🛡️ **Comprehensive error handling**
- ✅ **Data validation gates**
- 📊 **Quality scoring**

📖 **Full Details:** See [docs/ARCHITECTURE_COMPARISON.md](docs/ARCHITECTURE_COMPARISON.md)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Areas for Contribution

- 📝 New workflow templates
- 🔧 Infrastructure improvements
- 📚 Documentation enhancements
- 🐛 Bug fixes
- ✨ Feature requests

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [n8n](https://n8n.io/) - Fair-code workflow automation
- Powered by [OpenAI GPT-4](https://openai.com/) - AI analysis and report generation
- Infrastructure inspired by [n8n-io/n8n-hosting](https://github.com/n8n-io/n8n-hosting)

## 📞 Support

- 📖 **Documentation:** Check the `docs/` folder
- 🐛 **Issues:** [GitHub Issues](https://github.com/Spenny24/n8n-hosting/issues)
- 💬 **Discussions:** [GitHub Discussions](https://github.com/Spenny24/n8n-hosting/discussions)

---

**Made with ❤️ for automating consultant-grade AI Operating Model audits**

**⭐ Star this repo if you find it useful!**
