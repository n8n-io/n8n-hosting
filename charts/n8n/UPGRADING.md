# Upgrading the n8n chart

This file explains what to change when you move to a new major version of the chart. The [changelog](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/CHANGELOG.md) lists every release, including any upgrade notes for minor and patch releases.

## Upgrading to 2.0

Chart 2.0 is still in development. This section grows as each 2.0 change lands, and its guidance may change before 2.0.0 is released.

### Before you upgrade

Render your values against the new chart before you run `helm upgrade`:

```bash
helm template n8n oci://ghcr.io/n8n-io/n8n-helm-chart/n8n --version <new-version> -f my-values.yaml > /dev/null
```

The render fails on every values key that 2.0 retired, and names the replacement for each one. Work through the list until the render passes. Then read the sections below for any other changes that apply to your install, and run `helm upgrade` with the same values file.

### Values validation

If your values file sets a key the chart no longer reads, the render fails. The message names each such key and what replaces it, all in one render. The chart stops rather than ignoring the key, so a setting cannot quietly stop working. See [decision 0020](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0020-retired-values-keys-fail-the-render.md).

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
