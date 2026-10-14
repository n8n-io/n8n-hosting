# Upgrading the n8n chart

This file lists what you must change when you move to a new major version of the chart. Minor and patch releases need no changes to your values. The [changelog](CHANGELOG.md) lists every release.

## Upgrading to 2.0

### Before you upgrade

Render your values against the new chart before you run `helm upgrade`:

```bash
helm template n8n oci://ghcr.io/n8n-io/n8n-helm-chart/n8n --version <new-version> -f my-values.yaml > /dev/null
```

The render fails on every value you need to change, and names the fix for each one. Work through the list until the render passes. Then run `helm upgrade` with the same values file.

### Values validation

If your values file sets a key the chart no longer reads, the render fails. The message names each such key and what replaces it, all in one render. The chart stops rather than ignoring the key, so a setting cannot quietly stop working. See [decision 0018](decisions/0018-retired-values-keys-fail-the-render.md).

### Database

### Secrets and host settings

### Environment variables

### Task runners

### Binary data and S3

### Ingress and cloud integration

### Security contexts

### Network policy

### Persistence

### Changed defaults

### n8n 3.0
