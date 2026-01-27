# n8n Workflow Catalog

This directory contains production-ready n8n workflows for AI Operating Model audits and related automation tasks.

## 📊 Quick Reference

| Workflow | Version | Use Case | Cost/Run | Execution Time | Output |
|----------|---------|----------|----------|----------------|--------|
| **Improved AI Operating Model** | V4 | Production audits | $0.21 | ~65s | 3,000 words |
| **Premium Google Sheets** | Premium | Client deliverables | $0.99 | ~90s | 6,000-8,000 words |
| **Premium Report** | Premium | Airtable-based audits | $0.99 | ~90s | 6,000-8,000 words |
| **Google Sheets Edition** | Standard | Basic audits | $0.006 | ~80s | 1,500 words |
| **Financial Deep-Dive** | Enterprise | CFO-grade analysis | $1.20 | ~120s | 8,000+ words |
| **AI-Powered Lead Research** | Sales | Lead research | $0.05 | ~45s | Personalized emails |

> ⚠️ **Security Note:** One workflow (AI Op Model - Lead Gen) was removed due to exposed API credentials. If you need lead generation capabilities, use the AI-Powered Lead Research workflow with proper credential configuration.

---

## 🚀 Production Workflows

### 1. Improved AI Operating Model Workflow (V4) ⭐ RECOMMENDED

**File:** `improved_ai_operating_model_workflow.json`

**Description:** Production-ready V4 workflow with 50% faster execution through parallel processing. Optimized for cost and performance with comprehensive error handling.

**Use Case:**
- Internal audits
- Regular client assessments
- High-volume audit scenarios (10+ per month)

**Key Features:**
- ⚡ Parallel report generation (4 GPT calls simultaneously)
- 🛡️ Comprehensive error handling
- ✅ Data validation gates
- 📊 Quality scoring
- 🔧 Shared utilities for consistency
- 💾 Supabase pattern learning

**Architecture:**
- **V4 optimized** - 43 nodes (down from 65 in V3)
- **Parallel execution** - Report generation 69% faster
- **Cost-optimized** - 40% cheaper than V3 ($0.21 vs $0.35)

**Output Sections:**
1. Executive Overview (1,000 words)
2. Current State Assessment (1,200 words)
3. Future State Vision (1,500 words)
4. Governance Framework (800 words)

**Required Credentials:**
- Google Drive OAuth2
- Google Sheets OAuth2
- OpenAI API Key
- Supabase API Key
- Slack OAuth2

**Cost Breakdown:**
- GPT-4o-mini API calls: $0.19
- Data processing: $0.02
- **Total:** $0.21 per audit

**Documentation:** See [../docs/ARCHITECTURE_COMPARISON.md](../docs/ARCHITECTURE_COMPARISON.md)

---

### 2. Premium Google Sheets Edition ⭐ CLIENT-READY

**File:** `workflow_premium_google_sheets.json`

**Description:** Consultant-grade reports (6,000-8,000 words) using GPT-4 with no Airtable dependency. Perfect for client deliverables.

**Use Case:**
- Client-facing deliverables
- High-value proposals
- Detailed consulting reports
- When quality > cost

**Key Features:**
- 📈 **GPT-4** for all analysis (upgraded from GPT-4o-mini)
- 📊 **6+ detailed tables** (RACI, Cost Analysis, Risk Matrix, etc.)
- 💰 **Advanced financial analysis** (TCO, NPV, IRR, Cash Flow)
- 🎯 **8 comprehensive sections**
- 📋 **4-phase implementation roadmap**
- ⚠️ **Risk assessment matrix**

**Output Sections:**
1. Executive Overview (1,000-1,500 words)
2. Current State Assessment (1,200-1,800 words) + Inefficiency Table
3. Future State Vision (2,000-2,500 words) + 3 Architecture Tables
4. Financial Analysis & ROI + Cost Breakdown Tables
5. Implementation Roadmap (4 phases)
6. Risks & Mitigation + Risk Matrix
7. Governance & Decision Framework
8. Next Steps & Call to Action

**Required Credentials:**
- Google Drive OAuth2
- Google Sheets OAuth2
- OpenAI API Key (GPT-4 access required)
- Slack OAuth2

**Cost Breakdown:**
- GPT-4 API calls: $0.95
- Data processing: $0.04
- **Total:** $0.99 per audit

**Value Proposition:** $0.99 cost vs $15K-$50K consulting value = 99.998% savings

**Documentation:** See [../docs/PREMIUM_WORKFLOW_README.md](../docs/PREMIUM_WORKFLOW_README.md)

---

### 3. Premium Report (Airtable Edition)

**File:** `workflow_premium_report.json`

**Description:** Same premium quality as Google Sheets edition but uses Airtable as primary data source.

**Use Case:**
- Organizations with existing Airtable workflows
- Teams requiring Airtable's relational database features
- When Airtable is already in tech stack

**Key Features:**
- Same premium output as Google Sheets edition
- Airtable-native data collection
- Relational data handling
- Automated record creation

**Required Credentials:**
- Airtable API Token (in addition to Google credentials)
- Google Drive OAuth2
- OpenAI API Key
- Slack OAuth2

**Cost:** $0.99 per audit (same as Google Sheets premium)

**Note:** Requires active Airtable subscription

---

### 4. Google Sheets Edition (Standard)

**File:** `workflow_google_sheets_edition.json`

**Description:** Lightweight version using GPT-4o-mini. Ultra-low cost for testing and internal audits.

**Use Case:**
- Testing and development
- Internal audits (not client-facing)
- High-volume scenarios where cost is critical
- Learning and experimentation

**Key Features:**
- 💸 Ultra-low cost ($0.006 per run)
- 📊 Google Sheets only (no Airtable needed)
- ⚡ Fast execution (~80 seconds)
- ✅ Data Cleaner V3 with fallback data

**Output:** Basic 4-section report (~1,500 words)

**Cost Breakdown:**
- GPT-4o-mini API calls: $0.005
- Data processing: $0.001
- **Total:** $0.006 per audit

**Best For:** Running 100+ audits per month

---

## 💼 Enterprise Workflows

### 5. AI Operating Model - Financial Deep-Dive Edition

**File:** `AI Operating Model - Financial Deep-Dive Edition.json`

**Description:** CFO-grade financial analysis with advanced modeling (TCO, NPV, IRR, cash flow projections, sensitivity analysis).

**Use Case:**
- Board presentations
- Investment decisions
- CFO/Finance team reviews
- Detailed ROI justification

**Key Features:**
- 📊 **Advanced Financial Modeling**
  - Total Cost of Ownership (TCO) analysis
  - Net Present Value (NPV) calculations
  - Internal Rate of Return (IRR)
  - 5-year cash flow projections
  - Sensitivity analysis tables
  - Break-even analysis
- 💰 **Multi-scenario modeling** (Conservative, Moderate, Aggressive)
- 📈 **Year-by-year financial projections**
- 🎯 **Investment-grade analysis**

**Output:** 8,000+ word report with 8+ financial tables

**Cost:** $1.20 per audit

**Best For:** High-stakes decisions requiring financial rigor

**Documentation:** See [../docs/CONSULTANT_GRADE_ENHANCEMENTS.md](../docs/CONSULTANT_GRADE_ENHANCEMENTS.md)

---

## 🎯 Sales & Lead Generation Workflows

### 6. AI-Powered Lead Research & Personalized Email Generation

**File:** `_AI-Powered Lead Research & Personalized Email Generation with Groq & Google Sheets.json`

**Description:** Deep lead research with AI-powered personalization for cold outreach.

**Use Case:**
- Sales development (SDR/BDR)
- Personalized outbound campaigns
- Account-based marketing
- Partnership outreach

**Key Features:**
- 🔎 Deep company research
- 👤 Decision-maker identification
- 💬 Personalized email drafting
- 📊 Research data structured in Google Sheets
- 🚀 Groq AI for speed and cost efficiency

**Output:**
- Detailed company profile
- Pain point analysis
- 3 personalized email variants
- Follow-up sequence recommendations

**Cost:** $0.05 per lead

**Execution Time:** ~45 seconds per lead

---

## 🔧 Setup Instructions

### Prerequisites

Before importing any workflow:

1. **n8n Instance** (v1.0+)
   - Self-hosted or n8n Cloud
   - Sufficient memory (8GB recommended for Premium workflows)

2. **Required Accounts & API Keys**
   - Google Cloud Project (Drive + Sheets APIs enabled)
   - OpenAI API Key with billing enabled
   - Slack Workspace (for notifications)
   - Supabase Project (optional, for pattern learning)
   - Airtable Account (only for Airtable workflows)
   - Groq API Key (only for lead gen workflows)

### Import Steps

1. **Import Workflow**
   ```
   n8n Web Interface → Workflows → Add Workflow → Import from File
   ```

2. **Configure Credentials**
   - Click on each node with a red warning icon
   - Add/select credentials for the service
   - Test connection

3. **Update Configuration**
   - Open "Set Client Config" node
   - Update `client_name`
   - Update Google Sheets IDs (if using your own sheets)
   - Adjust any environment-specific settings

4. **Test Run**
   - Click "Execute Workflow"
   - Monitor execution logs
   - Verify outputs (Google Drive, Sheets, Slack)

5. **Review Costs**
   - Check OpenAI usage dashboard
   - Set billing alerts ($10-50/month recommended)
   - Monitor per-workflow costs

### Google Sheets Setup

Most workflows require a Google Sheets document with specific tabs:

**Required Sheets:**
1. **RACI_Matrix** - Process ownership data
   - Columns: `Process/Task`, `Responsible`, `Accountable`, `Consulted`, `Informed`, `Tool Used`, `Manual %`

2. **Tool_Inventory** - Technology stack
   - Columns: `ToolName`, `Purpose`, `UserCount`, `AnnualCost`

3. **KPI_Snapshot** - Performance metrics
   - Columns: `Metric`, `Value` (or `Vale` - typo supported)

4. **Client_Models** - Results storage
   - Columns: `Audit_ID`, `Client_Name`, `Recommended_Scenario`, `ROI_3Year`, `Annual_Saving`, `Implementation_Cost`, `FTE_Saved`, `Executive_Summary`, `Status`, `Created_At`

📖 **Detailed Guide:** [../docs/GOOGLE_SHEETS_SETUP_GUIDE.md](../docs/GOOGLE_SHEETS_SETUP_GUIDE.md)

---

## 💰 Cost Comparison

### Monthly Cost Scenarios

**Scenario 1: Small Team (10 audits/month)**
- Standard: $0.06/month
- Improved V4: $2.10/month
- Premium: $9.90/month

**Scenario 2: Agency (50 audits/month)**
- Standard: $0.30/month
- Improved V4: $10.50/month
- Premium: $49.50/month

**Scenario 3: Enterprise (200 audits/month)**
- Standard: $1.20/month
- Improved V4: $42.00/month
- Premium: $198.00/month

**Scenario 4: Mixed Usage (7 Standard + 3 Premium)**
- Total: ~$3.00/month

### Cost vs Value

| Workflow | Cost | Comparable Consulting Value | Savings |
|----------|------|----------------------------|---------|
| Standard | $0.006 | $5,000 - $10,000 | 99.99% |
| Improved V4 | $0.21 | $10,000 - $20,000 | 99.998% |
| Premium | $0.99 | $15,000 - $50,000 | 99.998% |
| Financial Deep-Dive | $1.20 | $25,000 - $75,000 | 99.998% |

📊 **Detailed Analysis:** [../docs/COST_ANALYSIS.md](../docs/COST_ANALYSIS.md)

---

## 🏗️ Workflow Architecture

All workflows follow a common architecture pattern:

```
┌─────────────────────────────────┐
│ 1. Trigger & Configuration      │
│    - Manual/Scheduled/Webhook   │
│    - Environment validation     │
│    - Client configuration       │
└─────────────────────────────────┘
              ↓
┌─────────────────────────────────┐
│ 2. Data Collection (Parallel)   │
│    - Google Sheets              │
│    - Airtable (if applicable)   │
│    - Google Drive documents     │
└─────────────────────────────────┘
              ↓
┌─────────────────────────────────┐
│ 3. Data Processing              │
│    - Data Cleaner V3            │
│    - Validation & fallbacks     │
│    - Quality scoring            │
└─────────────────────────────────┘
              ↓
┌─────────────────────────────────┐
│ 4. AI Analysis (Parallel)       │
│    - Inefficiency analysis      │
│    - AI fit mapping             │
│    - Architecture design        │
│    - ROI simulation             │
└─────────────────────────────────┘
              ↓
┌─────────────────────────────────┐
│ 5. Report Generation (Parallel) │
│    - Executive summary          │
│    - Current state              │
│    - Future vision              │
│    - Implementation plan        │
└─────────────────────────────────┘
              ↓
┌─────────────────────────────────┐
│ 6. Output & Notifications       │
│    - Google Drive upload        │
│    - Sheets/Airtable update     │
│    - Slack notification         │
│    - Pattern learning           │
└─────────────────────────────────┘
```

### V3 vs V4 Architecture

**V3 (Sequential):**
- 65 nodes
- 131s execution time
- $0.35 per audit
- No error handling
- Manual data validation

**V4 (Parallel):**
- 43 nodes (34% reduction)
- 65s execution time (50% faster)
- $0.21 per audit (40% cheaper)
- Comprehensive error handling
- Automated data validation

📖 **Full Comparison:** [../docs/ARCHITECTURE_COMPARISON.md](../docs/ARCHITECTURE_COMPARISON.md)

---

## 🔍 Troubleshooting

### Common Issues

**1. "Credentials not found" Error**
- **Solution:** Configure credentials in n8n settings
- Navigate to: Settings → Credentials → Add Credential
- Select service type and authenticate

**2. "No data returned from Google Sheets"**
- **Solution:** Check sheet IDs in "Set Client Config" node
- Verify Google Sheets API is enabled
- Confirm OAuth permissions include Sheets access
- Check sheet name matches exactly (case-sensitive)

**3. "OpenAI API rate limit exceeded"**
- **Solution:** Upgrade OpenAI tier or add delays between calls
- Premium workflows may need Tier 2+ OpenAI access
- Add 2-5 second delays between parallel GPT calls

**4. "Workflow execution failed with parse error"**
- **Solution:** GPT response parsing issue
- Check error logs for specific node
- V4 workflows have automatic fallbacks
- May need to adjust GPT temperature/prompts

**5. "Google Drive upload failed"**
- **Solution:** Check Drive API quota
- Verify OAuth includes Drive write permissions
- Ensure target folder ID is correct

### Performance Optimization

**For High-Volume Usage:**
1. Use Standard workflow for testing
2. Batch audits outside business hours
3. Enable caching where possible
4. Monitor OpenAI quota usage
5. Consider Groq for non-critical analysis (10x cheaper)

**For Cost Optimization:**
1. Use Standard for internal audits
2. Reserve Premium for client deliverables
3. Optimize prompts to reduce token usage
4. Cache common analysis results
5. Use workflow conditionals to skip unnecessary steps

---

## 📈 Roadmap & Enhancements

### Planned Improvements

**Q1 2026:**
- Google Drive trigger (auto-generate reports from uploaded docs)
- Change management framework
- Industry benchmarking

**Q2 2026:**
- Architecture diagram auto-generation
- Industry-specific templates
- Interactive ROI calculator

**Q3 2026:**
- Multi-language support
- Custom branding options
- White-label reports

📋 **Full Roadmap:** [../docs/CONSULTANT_GRADE_ENHANCEMENTS.md](../docs/CONSULTANT_GRADE_ENHANCEMENTS.md)

---

## 🤝 Contributing

Want to contribute a workflow or enhancement?

1. Fork the repository
2. Create workflow in n8n
3. Export as JSON
4. Add to this directory with descriptive name
5. Update this README with workflow details
6. Submit pull request

**Workflow Naming Convention:**
- `workflow_[name]_[version].json` for variants
- `[Feature Name] - [Edition].json` for major workflows
- Use descriptive, searchable names

---

## 📚 Additional Resources

### Documentation
- [Quick Start Guide](../docs/QUICK_START.md)
- [Google Sheets Setup](../docs/GOOGLE_SHEETS_SETUP_GUIDE.md)
- [Premium Workflow Guide](../docs/PREMIUM_WORKFLOW_README.md)
- [Cost Analysis](../docs/COST_ANALYSIS.md)
- [Architecture Comparison](../docs/ARCHITECTURE_COMPARISON.md)

### Utilities
- [Data Cleaner V3 Code](../scripts/DATA_CLEANER_V3_CODE.js)
- [Environment Guard Fix](../scripts/ENVIRONMENT_GUARD_FIX.js)
- [Update Premium Prompts](../scripts/update_premium_prompts.py)

### Support
- [GitHub Issues](https://github.com/Spenny24/n8n-hosting/issues)
- [GitHub Discussions](https://github.com/Spenny24/n8n-hosting/discussions)

---

**Last Updated:** 2026-01-14
**Total Workflows:** 6
**Average Cost per Audit:** $0.21 - $1.20 depending on workflow

---

## 🔒 Security Note

This repository previously contained a workflow file with an exposed API key, which has been removed for security. If you cloned this repository before 2026-01-14, please:

1. Rotate any API keys used in your workflows
2. Ensure all credentials are stored in n8n's credential manager, not hardcoded
3. Never commit workflow files with embedded credentials
4. Use the `.env.example` templates for configuration

For security concerns, see [SECURITY.md](../SECURITY.md).
