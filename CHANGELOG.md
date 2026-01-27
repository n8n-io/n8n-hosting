# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive README.md with project overview, features, and deployment guides
- Security policy (SECURITY.md) with best practices and vulnerability reporting
- MIT License file
- .gitignore for environment files and sensitive data
- .env.example templates for all deployment options
- CI/CD pipeline with workflow validation, security scanning, and documentation linting
- Dependabot configuration for automated dependency updates
- This CHANGELOG.md file

### Changed
- Improved repository structure and documentation organization

### Security
- Protected sensitive .env files from being committed
- Added security scanning to CI/CD pipeline
- Documented security best practices

## [1.0.0] - 2026-01-03

### Added
- **Premium Workflow** - Consultant-grade reports (6,000-8,000 words) with GPT-4
- **Data Cleaner V3** - Flexible field matching, typo support, fallback data
- **Google Sheets Edition** - No Airtable subscription required
- **Financial Deep-Dive** - Advanced ROI calculations with TCO, NPV, IRR
- Multiple deployment options:
  - Docker Compose with PostgreSQL
  - Docker Compose with Worker (horizontal scaling)
  - Kubernetes deployment
  - Caddy with automatic SSL
- Comprehensive documentation:
  - Quick Start Guide
  - Google Sheets Setup Guide
  - Architecture Comparison (V3 vs V4)
  - Cost Analysis
  - Premium Report Specification
  - Workflow Improvements Guide

### Changed
- **V4 Architecture** - 50% faster execution with parallel processing
- Reduced node count by 34% (65 → 43 nodes)
- Optimized token usage - 40% cost reduction
- Enhanced error handling and data validation

### Fixed
- RACI, KPI, and Tool data population from Google Sheets
- Google Sheets Write node empty field expressions
- Environment Guard node compatibility (process.env → $env)
- Support for "Vale" typo in KPI column headers

## [0.9.0] - 2025-12-XX

### Added
- Lead Generation workflow with Groq AI
- AI Operating Model - Financial Deep-Dive Edition
- Session summary for context transfer
- Enhancement roadmaps for future features

### Changed
- Upgraded Premium workflow from GPT-4o-mini to GPT-4
- Increased token limits for consultant-grade output
- Enhanced report structure with 8 sections and 6+ tables

## [0.8.0] - 2025-11-XX

### Added
- Premium Report Workflow with detailed tables
- Cost tracking and analysis
- Pattern learning with Supabase integration
- Slack notifications for workflow completion

### Fixed
- Cost Analysis table population
- Implementation cost calculations

## [0.7.0] - 2025-10-XX

### Added
- Google Sheets Edition workflow (no Airtable required)
- Standalone Data Cleaner v3 code
- Environment Guard fix for n8n compatibility

### Changed
- Updated Google Sheets data collection nodes
- Improved RACI matrix processing

## [0.6.0] - 2025-09-XX

### Added
- V4 Production-Ready workflow with parallel execution
- Shared Utilities node for reusable functions
- Comprehensive error handling
- Data validation gates

### Changed
- Refactored report generation for parallel execution (69% faster)
- Optimized data collection layer
- Reduced API costs through token optimization

### Performance
- Report generation: 71s → 22s (69% improvement)
- Total execution time: 131s → 65s (50% improvement)
- Cost per audit: $0.35 → $0.21 (40% reduction)

## [0.5.0] - 2025-08-XX

### Added
- Basic CI workflow (blank.yml)
- Multiple Docker Compose configurations
- Kubernetes deployment manifests

### Changed
- Project structure with deployment options

## Earlier Versions

See git history for earlier changes:
```bash
git log --oneline --reverse
```

## Version History Summary

| Version | Date | Key Features | Cost/Audit |
|---------|------|--------------|------------|
| 0.5.0 | 2025-08 | Initial deployment configs | N/A |
| 0.6.0 | 2025-09 | V4 architecture, parallel execution | $0.21 |
| 0.7.0 | 2025-10 | Google Sheets Edition | $0.006 |
| 0.8.0 | 2025-11 | Premium reports | $0.99 |
| 0.9.0 | 2025-12 | Financial deep-dive | $1.20 |
| 1.0.0 | 2026-01 | Production-ready, full docs | $0.21-$0.99 |

## Upgrade Guide

### From 0.9.0 to 1.0.0

1. **Security Updates (IMPORTANT):**
   ```bash
   # Create .env files from examples
   cd docker-compose/withPostgres
   cp .env.example .env
   # Edit .env with your credentials
   ```

2. **Update deployment:**
   ```bash
   docker-compose down
   git pull origin main
   docker-compose up -d
   ```

3. **Re-import workflows:**
   - Backup existing workflows
   - Import updated workflow files from `workflows/` directory
   - Reconfigure credentials if needed

### Breaking Changes

**1.0.0:**
- `.env` files removed from repository (use `.env.example`)
- Credentials must be reconfigured after update

**0.6.0:**
- Node structure changed significantly
- Workflows from v0.5.0 are incompatible
- Manual migration required

## Contributing

When contributing, please:
1. Update CHANGELOG.md with your changes
2. Follow [Keep a Changelog](https://keepachangelog.com/) format
3. Use semantic versioning for version numbers
4. Document breaking changes clearly

## Links

- [Repository](https://github.com/Spenny24/n8n-hosting)
- [Issues](https://github.com/Spenny24/n8n-hosting/issues)
- [Discussions](https://github.com/Spenny24/n8n-hosting/discussions)

---

**Legend:**
- `Added` - New features
- `Changed` - Changes in existing functionality
- `Deprecated` - Soon-to-be removed features
- `Removed` - Removed features
- `Fixed` - Bug fixes
- `Security` - Security improvements
- `Performance` - Performance improvements
