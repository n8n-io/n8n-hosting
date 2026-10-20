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

The chart's Secret holds only secrets. Host, port and protocol are no longer read from it. See [decision 0012](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0012-env-as-per-component-maps.md).

| If your values set | Do this |
|---|---|
| `secretRefs.env.N8N_HOST` or `secretRefs.env.N8N_PROTOCOL` | Remove them. n8n builds its public URLs from `editor.url` and `webhook.url`. If you still need either variable, set it in `env.shared`. |
| `secretRefs.env.N8N_PORT` | Remove it. The chart sets `N8N_PORT` from `service.port` on every n8n process, workers included. |

If you use `secretRefs.existingSecret`, the Secret needs only the `N8N_ENCRYPTION_KEY` key, or no key at all if you set `secretRefs.env.N8N_ENCRYPTION_KEY_FILE`. The chart reads that one key by name and ignores the rest of the Secret. A Secret that still holds `N8N_HOST`, `N8N_PORT` and `N8N_PROTOCOL` still renders, but n8n no longer receives those values.

In 1.x, n8n built its public URLs from `N8N_HOST` and `N8N_PROTOCOL` when no `editor.url`, `webhook.url` or ingress host was set. If your install relies on that, set `editor.url` and `webhook.url` before you upgrade. Otherwise n8n builds its URLs from `localhost`, so the webhook and OAuth callback URLs it shows point at `localhost`. After that, you can delete the three keys from the Secret.

If you set `license.activationKey` inline, the chart now stores it in the chart's Secret and the containers read it from there. You do not need to change anything. If `secretRefs.existingSecret` names the chart's own Secret (the release's full name), the render fails. Put the licence key in a Secret of your own and set `license.existingSecret` instead.

### Environment variables

You now set environment variables as one flat map per component. The chart renders them into one ConfigMap per component, and each container loads its ConfigMaps with `envFrom`. Maps merge across values files, so an overlay file only needs the variables it changes. See [decision 0012](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0012-env-as-per-component-maps.md).

The `extraEnv` and `extraEnvFrom` lists are removed. Move each entry to the map in this table:

| Removed list | Move its entries to |
|---|---|
| `config.extraEnv`, `redis.extraEnv`, `s3.storage.extraEnv` | `env.shared` |
| `queueMode.workerExtraEnv` | `env.worker` |
| `webhookProcessor.extraEnv` | `env.webhookProcessor` |
| `webhook.extraEnv` | `env.main` and `env.webhookProcessor` |
| `executions.extraEnv` | `env.main` and `env.worker` |
| `taskRunners.extraEnv` | `env.taskRunner` |
| `config.extraEnvFrom` | `envFrom.shared` |

A list entry `{name: X, value: Y}` becomes `X: Y`. For an entry with `valueFrom`, use the object under `valueFrom` as the value:

```yaml
# 1.x
config:
  extraEnv:
    - name: N8N_LOG_LEVEL
      value: "info"
    - name: N8N_SMTP_PASS
      valueFrom:
        secretKeyRef:
          name: smtp
          key: password

# 2.0
env:
  shared:
    N8N_LOG_LEVEL: info
    N8N_SMTP_PASS:
      secretKeyRef:
        name: smtp
        key: password
```

An empty list is ignored, so you only need to move the lists that hold entries.

`env.shared` reaches every n8n process: main, workers and webhook processors. It does not reach the task runner sidecar. Use `env.taskRunner` for the sidecar.

Check these behaviour changes:

- **A variable the chart sets cannot go in an `env` map.** The render fails and names the values key that sets it. Set that key instead. To replace the chart's value on purpose, use `chartEnvOverrides.<component>`. The chart lists the overrides in effect after install.
- **`envFrom` refs now win over the chart's ConfigMap values.** In 1.x the chart's variables took precedence over `config.extraEnvFrom`. In 2.0, `envFrom.shared` and `envFrom.<component>` load after the chart's ConfigMaps, so a key in them replaces the chart's value. Variables the chart reads from a Secret, such as the encryption key and database password, are in the container's `env` list and still win. Check that the ConfigMaps and Secrets you load hold only the keys you mean to set.
- **`webhook.timeout` is removed.** n8n never read the variable it set, so it had no effect. Remove it from your values.

Every pod restarts once on upgrade, because its environment moves into the new ConfigMaps. After that, a change to one component's map restarts only that component's pods.

### Task runners

### Binary data and S3

### Ingress and cloud integration

### Security contexts

The chart-wide `securityContext` block is retired. `podSecurityContext` and `containerSecurityContext` each have a `shared` block that applies to every pod or container. Each role block merges over `shared` field by field, and the role wins. Set a field to `null` to remove it. See [decision 0021](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0021-security-contexts-merge-over-shared.md).

Move your settings as follows:

| 1.x | 2.0 |
|---|---|
| `securityContext.fsGroup` | `podSecurityContext.shared.fsGroup` |
| `securityContext.runAsUser` | `podSecurityContext.shared.runAsUser` |
| `securityContext.runAsGroup` | `podSecurityContext.shared.runAsGroup` |
| `securityContext.enabled: true` | Remove it. The defaults apply without it. |
| `securityContext.enabled: false` | `podSecurityContext.shared: null` |

`runAsNonRoot: true` and the `RuntimeDefault` seccomp profile are now in `podSecurityContext.shared` too, so you can change or remove them. The container defaults are in `containerSecurityContext.shared`. A `containerSecurityContext.<role>` override from 1.x keeps working, because it now merges over `shared`.

A `podSecurityContext.<role>` block from 1.16 now merges over `shared` instead of replacing it. The render does not detect this. If the block left out a field to remove it, set that field to `null`.

On OpenShift, the restricted SCC assigns the UID and GID. In 1.x you set `securityContext.enabled: false`, or a `podSecurityContext.<role>` block without the IDs. In 2.0, remove the pinned IDs once for every pod:

```yaml
podSecurityContext:
  shared:
    fsGroup: null
    runAsUser: null
    runAsGroup: null
```

The pods keep `runAsNonRoot: true` and the `RuntimeDefault` seccomp profile. The chart's containers keep `allowPrivilegeEscalation: false` and drop all capabilities. Together these meet the `restricted` Pod Security Standard. Containers you add with `extraContainers` or `extraInitContainers` do not get the container defaults, so set their `securityContext` yourself.

### Network policy

### Persistence

### Changed defaults

`queueMode.workerConcurrency` is now empty by default, so workers start without a `--concurrency` flag and use n8n's default of 10.

In queue mode, the render fails if you set `queueMode.workerConcurrency` together with `executions.concurrency.productionLimit`, or together with `N8N_CONCURRENCY_PRODUCTION_LIMIT` in `env.shared` or `env.worker`. n8n uses the production limit as each worker's concurrency and ignores the flag. To keep the concurrency your workers run at today, keep `productionLimit` and remove `workerConcurrency`.

### n8n 3.0
