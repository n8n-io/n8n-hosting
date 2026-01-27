# Security Policy

## Supported Versions

We release patches for security vulnerabilities for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of n8n-hosting seriously. If you have discovered a security vulnerability, please report it to us privately.

### How to Report

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via one of the following methods:

1. **Email:** Send details to the repository maintainer
2. **GitHub Security Advisories:** Use the [Security tab](https://github.com/Spenny24/n8n-hosting/security/advisories/new) to report privately

### What to Include

Please include the following information in your report:

- Type of vulnerability (e.g., SQL injection, XSS, credential exposure)
- Full paths of source file(s) related to the vulnerability
- Location of the affected source code (tag/branch/commit or direct URL)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

### Response Timeline

- **Initial Response:** Within 48 hours of submission
- **Status Update:** Within 5 business days with next steps
- **Resolution Target:** Critical vulnerabilities within 30 days

## Security Best Practices

### For Deployment

#### 1. Environment Variables & Secrets

**DO:**
- ✅ Use `.env.example` as a template and create your own `.env` file
- ✅ Generate strong passwords (min 16 characters, mixed case, numbers, special chars)
- ✅ Use unique passwords for each service
- ✅ Generate encryption keys with: `openssl rand -base64 32`
- ✅ Store secrets in environment variables or secret management systems
- ✅ Rotate API keys and passwords regularly (every 90 days)

**DON'T:**
- ❌ Commit `.env` files to version control
- ❌ Use default credentials (like `changePassword`)
- ❌ Share credentials in plain text via email/chat
- ❌ Hardcode API keys in workflow JSON files
- ❌ Use the same password across multiple services

#### 2. Network Security

**DO:**
- ✅ Use SSL/TLS for all external connections (use Caddy deployment for auto-SSL)
- ✅ Restrict database access to localhost or private network
- ✅ Use firewall rules to limit exposed ports
- ✅ Enable HTTPS-only in production
- ✅ Use VPN for accessing internal services

**DON'T:**
- ❌ Expose PostgreSQL port (5432) to the internet
- ❌ Run n8n on default port 5678 without reverse proxy in production
- ❌ Allow unauthenticated access to n8n interface
- ❌ Use self-signed certificates in production

#### 3. API Key Security

**DO:**
- ✅ Use API keys with minimum required permissions
- ✅ Enable IP whitelisting where supported (OpenAI, Google Cloud)
- ✅ Set billing limits on OpenAI API ($10-50/month recommended)
- ✅ Monitor API usage for anomalies
- ✅ Store credentials in n8n's encrypted credential store, not in workflow nodes

**DON'T:**
- ❌ Share API keys between environments (dev/staging/prod)
- ❌ Log API keys in workflow execution logs
- ❌ Include API keys in error messages
- ❌ Store API keys in Google Sheets or Airtable

#### 4. Docker Security

**DO:**
- ✅ Use official Docker images only
- ✅ Keep Docker and images up to date
- ✅ Run containers with non-root user where possible
- ✅ Use Docker secrets for sensitive data in production
- ✅ Scan images for vulnerabilities regularly
- ✅ Limit container resources (CPU, memory)

**DON'T:**
- ❌ Run containers as root in production
- ❌ Mount host filesystem unnecessarily
- ❌ Use `:latest` tag in production (pin specific versions)
- ❌ Expose Docker daemon to network

#### 5. n8n Specific Security

**DO:**
- ✅ Enable n8n authentication (basic auth or OAuth)
- ✅ Use webhook authentication for public endpoints
- ✅ Validate and sanitize all user inputs in workflows
- ✅ Use n8n's built-in credential system
- ✅ Review workflow execution logs regularly
- ✅ Disable public workflow execution if not needed

**DON'T:**
- ❌ Share n8n instance across untrusted users
- ❌ Expose n8n editor publicly without authentication
- ❌ Trust user input without validation
- ❌ Allow arbitrary code execution from external sources
- ❌ Store sensitive data in workflow variables

### For Workflows

#### 1. Data Handling

**DO:**
- ✅ Sanitize data from external sources (Google Sheets, APIs)
- ✅ Validate data types and formats
- ✅ Use error handling for all external API calls
- ✅ Redact sensitive data in logs
- ✅ Encrypt data at rest (use encrypted volumes)

**DON'T:**
- ❌ Trust data from Google Sheets without validation
- ❌ Pass unsanitized user input to code nodes
- ❌ Log full request/response bodies containing credentials
- ❌ Store PII without encryption

#### 2. Code Execution

**DO:**
- ✅ Review all JavaScript code in Function nodes
- ✅ Use allowlisted modules only
- ✅ Validate input parameters in code nodes
- ✅ Use try-catch blocks for error handling
- ✅ Test code nodes in isolated environment first

**DON'T:**
- ❌ Use `eval()` with user input
- ❌ Execute arbitrary code from external sources
- ❌ Import untrusted npm packages
- ❌ Disable n8n's security features

### For Data Sources

#### 1. Google Sheets / Drive

**DO:**
- ✅ Use service accounts with minimum permissions
- ✅ Restrict sheet access to specific email addresses
- ✅ Use "View only" permissions for read-only workflows
- ✅ Audit sharing settings regularly
- ✅ Enable 2FA on Google accounts

**DON'T:**
- ❌ Make sheets publicly accessible
- ❌ Share edit permissions broadly
- ❌ Store raw credentials in sheets
- ❌ Trust sheet data without validation

#### 2. Airtable

**DO:**
- ✅ Use read-only API keys where possible
- ✅ Restrict base access to specific collaborators
- ✅ Review workspace permissions monthly
- ✅ Use Personal Access Tokens instead of API keys (when available)

**DON'T:**
- ❌ Share workspace API keys
- ❌ Use admin-level keys for read-only operations
- ❌ Expose base IDs publicly

#### 3. Database (PostgreSQL)

**DO:**
- ✅ Use separate database users for n8n
- ✅ Grant minimum required permissions
- ✅ Enable SSL for database connections
- ✅ Backup database regularly (encrypted backups)
- ✅ Use strong database passwords (20+ characters)

**DON'T:**
- ❌ Use `postgres` superuser for n8n
- ❌ Allow remote connections without SSL
- ❌ Store backups unencrypted
- ❌ Use default PostgreSQL port if exposed

## Known Security Considerations

### 1. Credential Storage

n8n encrypts credentials at rest using the `ENCRYPTION_KEY`. If this key is compromised, all stored credentials are at risk.

**Mitigation:**
- Store `ENCRYPTION_KEY` securely (use secret manager in production)
- Rotate encryption key periodically (requires credential re-entry)
- Use separate encryption keys per environment

### 2. Workflow Execution Context

Workflows run with the permissions of the n8n instance, which may have access to sensitive data.

**Mitigation:**
- Review workflow permissions regularly
- Implement approval workflows for sensitive operations
- Audit workflow changes via git
- Use separate n8n instances for different security zones

### 3. OpenAI API Data Usage

Data sent to OpenAI API may be used for model improvement unless you're on Enterprise plan.

**Mitigation:**
- Review OpenAI's data usage policy
- Use OpenAI Enterprise if handling sensitive data
- Redact PII before sending to GPT models
- Consider self-hosted models for highly sensitive data

### 4. Third-Party Dependencies

Docker images and npm packages may contain vulnerabilities.

**Mitigation:**
- Enable Dependabot for automated updates
- Review security advisories regularly
- Pin specific versions in production
- Test updates in staging first

## Incident Response

In case of a security incident:

1. **Contain:** Immediately revoke compromised credentials
2. **Assess:** Determine scope of data exposure
3. **Notify:** Report incident per reporting guidelines above
4. **Remediate:** Apply patches, rotate keys, update passwords
5. **Review:** Conduct post-incident review and update procedures

## Security Checklist

Before deploying to production, verify:

- [ ] `.env` files are not committed to git
- [ ] All services use strong, unique passwords
- [ ] SSL/TLS is enabled for all external connections
- [ ] Database is not exposed to internet
- [ ] n8n authentication is enabled
- [ ] API keys have minimum required permissions
- [ ] Billing limits are set on API providers
- [ ] Backups are configured and encrypted
- [ ] Firewall rules restrict unnecessary access
- [ ] Docker images are from official sources
- [ ] Dependabot or equivalent is enabled
- [ ] Security monitoring/logging is configured
- [ ] Incident response plan is documented
- [ ] Team knows how to report security issues

## Compliance

### GDPR Considerations

If processing EU citizen data:
- Implement data retention policies
- Provide data export capabilities
- Support right to deletion requests
- Document data processing activities
- Use data processing agreements with sub-processors (OpenAI, Google, etc.)

### HIPAA Considerations

This platform is **NOT** HIPAA-compliant by default. Do not process PHI without:
- Business Associate Agreements (BAA) with all service providers
- Encryption at rest and in transit
- Audit logging
- Access controls and authentication
- Risk assessment and security policies

## Resources

- [n8n Security Best Practices](https://docs.n8n.io/hosting/security/)
- [Docker Security Documentation](https://docs.docker.com/engine/security/)
- [OpenAI API Security](https://platform.openai.com/docs/guides/safety-best-practices)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

## Updates

This security policy is reviewed and updated quarterly. Last update: 2026-01-14

---

**Security is a shared responsibility. Stay vigilant and report concerns promptly.**
