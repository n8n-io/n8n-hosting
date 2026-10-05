# 0004. The chart sets a binary data mode only when S3 is enabled

Date: 2026-10-02
PR: https://github.com/n8n-io/n8n-hosting/pull/TBD

## Context

n8n stores binary data (files, images, attachments passed between nodes) in one of several places, chosen by `N8N_DEFAULT_BINARY_DATA_MODE`. n8n picks a default for each topology, and that default changes between n8n majors. From n8n 3.0 it is `filesystem` in regular mode and `database` in queue mode. `s3` mode needs a bucket and an n8n Business or Enterprise licence. The same bucket settings also serve execution data, through `N8N_EXECUTION_DATA_STORAGE_MODE`.

In queue mode, main, worker and webhook-processor pods each have their own disk. If binary data is written to `filesystem`, one pod writes it and another can't read it. n8n has no way to know the pods don't share a disk. The chart does.

## Decision

The chart leaves the mode to n8n unless `s3.enabled` is true. When it is, the chart sets the mode to `s3`. `s3.storage.mode` stays as an explicit setting, and the chart refuses to render if it says anything other than `s3` while S3 is on. This sits under "Fail loudly, never silently".

In queue mode, the chart also refuses `N8N_DEFAULT_BINARY_DATA_MODE=filesystem` in any of its `extraEnv` lists, because n8n doesn't support `filesystem` mode in queue mode. It can't see values set through `extraEnvFrom`.

Any other mode set through `extraEnv` is left alone, with S3 on or off. An `extraEnv` entry renders after the chart's own variable and wins, so it is the way to keep the bucket for execution data while binary data goes elsewhere.

## Consequences

- Turning on S3 is enough to store binary data in S3. Those installs need a Business or Enterprise licence, or n8n exits at boot.
- Values files that set `s3.storage.mode: filesystem` alongside `s3.enabled: true` fail to render until the line is removed or set to `s3`. Those installs had been writing binary data to each pod's local disk.
- Without S3, n8n's own default applies. The chart doesn't copy it, so it follows n8n when the default changes.
- The binary data mode has no values key of its own outside S3, so the checks read environment variables. A dedicated values key would let the chart check the mode directly.
- `filesystem` in queue mode is refused because no pods share a volume. A shared ReadWriteMany volume for binary data would make it valid, and the check would need to allow it.
