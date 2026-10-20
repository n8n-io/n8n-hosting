# 0022. The chart sets a binary data mode only when S3 is enabled

Date: 2026-10-02
PR: https://github.com/n8n-io/n8n-hosting/pull/220

## Context

n8n stores binary data (files, images, attachments passed between nodes) in one of several places, chosen by `N8N_DEFAULT_BINARY_DATA_MODE`. n8n picks a default for each topology: `database` in queue mode and `filesystem` otherwise. `s3` mode needs a bucket and an n8n Business or Enterprise licence. The same bucket settings also serve execution data, through `N8N_EXECUTION_DATA_STORAGE_MODE`.

In queue mode, main, worker and webhook-processor pods each have their own disk. If binary data is written to `filesystem`, one pod writes it and another cannot read it. n8n has no way to know the pods do not share a disk. The chart does.

## Decision

The chart leaves the mode to n8n unless `s3.enabled` is true. When it is, the chart sets the mode to `s3` and requires `license.enabled`, as decision 0005 does for multi-main. This sits under "Fail loudly, never silently".

The 1.x key `s3.storage.mode` is retired under decision 0020. With S3 on, only `s3` works, and with S3 off the key did nothing. Its 1.x default was `filesystem`, so many values files carry it without anyone having chosen it.

With S3 on, the mode is a variable the chart sets, so decision 0012 applies: an `env` map that sets it fails the render, and `chartEnvOverrides` replaces it on purpose. That is the way to keep the bucket for execution data while binary data goes elsewhere.

In queue mode, the chart also refuses `N8N_DEFAULT_BINARY_DATA_MODE=filesystem` in an `env` map or in `chartEnvOverrides`, for any n8n component. The pods do not share a disk, so one pod cannot read binary data that another pod writes. The chart cannot see a value held in a Secret or ConfigMap, through `envFrom` or a reference in an `env` map.

## Consequences

- Turning on S3 is enough to store binary data in S3. Those installs need a Business or Enterprise licence, or n8n exits at boot.
- `s3.enabled` without `license.enabled` fails to render. `license.enabled: true` with no key is accepted, for a licence activated in n8n or supplied another way.
- Values files that set `s3.storage.mode` fail to render until the line is removed. Installs that had it at `filesystem` with S3 on had been writing binary data to each pod's local disk.
- n8n keeps reading binary data it stored on disk before S3 was turned on, as long as the volume holding it is still mounted.
- Without S3, n8n's own default applies. The chart does not copy it, so it follows n8n when the default changes.
- The binary data mode has no values key of its own outside S3, so the queue-mode check reads environment variables. A dedicated values key would let the chart check the mode directly.
- `filesystem` in queue mode is refused because no pods share a volume. A shared ReadWriteMany volume for binary data would make it valid, and the check would need to allow it.
