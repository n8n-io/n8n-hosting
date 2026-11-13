# Upgrading the n8n chart

This file explains what to change when you move to a new major version of the chart. The [changelog](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/CHANGELOG.md) lists every release, including any upgrade notes for minor and patch releases.

## Upgrading to 2.0

Chart 2.0 is still in development. Its guidance may change before 2.0.0 is released.

Chart 2.0 runs n8n 3.0, so this upgrade moves both the chart and n8n. Follow the steps below in order. The sections after them describe each change, and the table in [Which sections apply to you](#which-sections-apply-to-you) tells you which ones to read.

### Upgrade steps

1. **Fix what n8n 3.0 breaks in your instance.** Open the Migration Report in n8n, under **Settings > Migration Report**, as an instance owner or admin. It lists the workflows and instance settings that n8n 3.0 breaks. Fix the issues marked "Upgrade blocked" and "Executions will fail" first. Some instance issues are environment variables, which you change in your values file in step 3. See n8n's [Migration Report guide](https://docs.n8n.io/changelog/v30-migration-tool) and [3.0 breaking changes](https://docs.n8n.io/changelog/v30-breaking-changes/).
2. **Back up your database.** The move to n8n 3.0 is one way. To go back to n8n 2.x, you restore this backup. Follow n8n's [Back up and restore](https://docs.n8n.io/deploy/host-n8n/keep-n8n-running/backup-and-restore/) guide. Keep the Secret that holds `N8N_ENCRYPTION_KEY` with the backup, because a restored database cannot be decrypted without it. See [Roll back](#roll-back).
3. **Migrate your values file.** Many values keys change in 2.0. Pull the chart, and run the [migration script](#the-migration-script) over your values file. It writes a new values file, and a report of what it changed, for you to review.

   ```bash
   helm pull oci://ghcr.io/n8n-io/n8n-helm-chart/n8n --version <new-version> --untar
   bash n8n/scripts/migrate-values.sh my-values.yaml > my-values-2.0.yaml
   ```

4. **Render the new values file** against the new chart:

   ```bash
   helm template n8n oci://ghcr.io/n8n-io/n8n-helm-chart/n8n --version <new-version> -f my-values-2.0.yaml > /dev/null
   ```

   The render will fail on any value key that 2.0 retired, and will name the replacement for each one.
5. **Read the sections that apply to you.** Start with [Changes the render does not catch](#changes-the-render-does-not-catch). A passing render does not mean these are handled.
6. **Upgrade.** Run `helm upgrade` with the new values file, passed with `-f`. Do not use `--reuse-values`. It keeps the defaults of the chart version you installed as well as your own values, so the 2.0 render fails on 1.x defaults that 2.0 no longer reads. If you no longer have your values file, `helm get values <release> -o yaml` prints the values you set. `--reset-then-reuse-values`, in Helm 3.14 or later, reuses your values with the new chart's defaults, and also works.
7. **Check the upgrade.** See [Check the upgrade](#check-the-upgrade).

### The migration script

The script needs [yq](https://github.com/mikefarah/yq) v4. It moves or removes every values key that 2.0 retired, turns the `extraEnv` lists into `env` maps, and renames or removes the environment variables that n8n 3.0 no longer reads. It prints a report of what it changed, and of what you need to check yourself. Where it cannot decide for you, it keeps the 1.x behaviour and says so in the report. Keys it does not know pass through unchanged.

The script has these limits:

- It reads plain YAML only. It does not read helmfile `.gotmpl` files, or values that Argo CD or another tool generates from templates.
- It never reads the contents of a Secret. If a Secret needs a change, such as a new key, the report names it. You make the change yourself.
- It reads one values file. A setting in another values file, such as one you pass with a second `-f`, is not migrated.

### Which sections apply to you

Every install needs [Values validation](#values-validation), [Environment variables](#environment-variables), [Task runners](#task-runners) and [n8n 3.0](#n8n-30). Read the others when your install matches the row.

| If your install | Read |
|---|---|
| Runs in queue mode | [Worker concurrency](#worker-concurrency), [Worker probes](#worker-probes) |
| Sets `secretRefs.existingSecret` | [Secrets and host settings](#secrets-and-host-settings) |
| Sets `database.useExternal`, `redis.useExternal` or `database.type: sqlite` | [Database](#database) |
| Sets `s3.enabled: true` | [Binary data and S3](#binary-data-and-s3) |
| Has an Ingress or HTTPRoute, or sets `editor.url`, `webhook.url` or `webhookProcessor.enabled` | [Ingress and cloud integration](#ingress-and-cloud-integration) |
| Runs on EKS with an IAM role, or uses ingress-nginx sticky sessions | [Ingress and cloud integration](#ingress-and-cloud-integration) |
| Runs on OpenShift, or sets `securityContext` or `podSecurityContext` | [Security contexts](#security-contexts) |
| Sets `networkPolicy.enabled: true` | [Network policy](#network-policy) |
| Sets `persistence.enabled: true`, or was installed with Helm 4 | [Persistence](#persistence), and [Storage directory](#storage-directory) under n8n 3.0 |
| Adds containers with `extraContainers` or `extraInitContainers` | [Pod defaults](#pod-defaults), [Security contexts](#security-contexts) |
| Mounts its own task runner config, or builds its own n8n image | [Image changes](#image-changes) |

### Changes the render does not catch

The render fails on every retired key, but these changes pass the render and may change how your install behaves. Check each one that applies to you.

- `envFrom` refs now win over the chart's ConfigMap values. See [Environment variables](#environment-variables).
- With `secretRefs.existingSecret`, the Secret needs a task runner token, or the pods do not start. See [Task runners](#task-runners).
- Task runners are on by default, and add a container to each worker pod, or to main in standalone mode. See [Task runners](#task-runners).
- With `s3.enabled: true`, n8n now stores binary data in the bucket. See [Binary data and S3](#binary-data-and-s3).
- Webhook URLs can move to another scheme or host. See [Ingress and cloud integration](#ingress-and-cloud-integration).
- With webhook processors and an Ingress, the chart now renders a webhook Ingress. On the AWS Load Balancer Controller this creates a second load balancer. See [Ingress and cloud integration](#ingress-and-cloud-integration).
- With an Ingress or HTTPRoute, n8n now sees the client's IP address instead of the proxy's. See [Ingress and cloud integration](#ingress-and-cloud-integration).
- A `podSecurityContext.<role>` block now merges over `shared` instead of replacing it. See [Security contexts](#security-contexts).
- With `networkPolicy.enabled`, the policy now allows all egress by default, and the `ingress` and `egress` lists you set now take effect. See [Network policy](#network-policy).
- A worker probe that runs `pgrep` always passes. See [Worker probes](#worker-probes).
- A main pod with a `ReadWriteOnce` volume now uses the `Recreate` strategy, so each upgrade has a short outage. See [Persistence](#persistence).
- The pods no longer get service links, a Kubernetes API token or a Role. See [Pod defaults](#pod-defaults).
- n8n 3.0 changes several defaults, such as the Code node timeout and the Content-Security-Policy. See [n8n 3.0](#n8n-30).

### Values validation

The schema rejects any values key it does not know, so a typo or a key from another chart fails the install or upgrade instead of being ignored. Helm checks the schema before it renders, and names each key and where it sits.

```
- at '/queueMode': additional properties 'workerReplicas' not allowed
```

Remove each key the error names, or correct its spelling against [values.yaml](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/values.yaml). Free-form blocks still accept any key: annotations, labels, `nodeSelector`, `tolerations`, `affinity`, `resources`, `strategy`, `dnsConfig` and the `extra*` lists. If you keep your own top-level keys, for YAML anchors or for values your `extraObjects` read through `tpl`, move them under `global`. To skip the schema check for one release, Helm 3.16 and later take `--skip-schema-validation`. The chart's own checks still run.

### Database

`database.type` alone chooses the database: `postgresdb`, the default, or `sqlite`.

| If your values set | Do this |
|---|---|
| `database.useExternal` | Remove it. Leave `database.type` as it is. |
| `redis.useExternal` | Remove it. Nothing replaces it. Queue mode connects to the Redis at `redis.host`. |
| `redis.worker.maxStalledCount` | Remove it. n8n 2.0 removed the setting, so it had no effect. |
| `database.ssl.key` | The chart never read it. Put the client key in a Secret, and set `database.ssl.existingSecret.name` and `database.ssl.existingSecret.keyKey`.|

If your values set `database.type: sqlite` without `useExternal`, the chart stops passing PostgreSQL settings to n8n. n8n did not use them with SQLite.

### Secrets and host settings

The chart's Secret holds only secrets. Host, port and protocol are no longer read from it.

| If your values set | Do this |
|---|---|
| `secretRefs.env.N8N_HOST` or `secretRefs.env.N8N_PROTOCOL` | Remove them. n8n builds its public URLs from `editor.url` and `webhook.url`. If you still need either variable, set it in `env.shared`. |
| `secretRefs.env.N8N_PORT` | Remove it. The chart sets `N8N_PORT` from `service.port` on every n8n process, workers included. |
| `secretRefs.existingSecret` naming the chart's own Secret (the release's full name), with `license.activationKey` | Put the licence key in a Secret of your own, and set `license.existingSecret`. The render fails until you do. |

If you use `secretRefs.existingSecret`, the chart reads these keys from it by name, and ignores the rest:

| Key | When it is needed |
|---|---|
| `N8N_ENCRYPTION_KEY` | Always, unless you set `secretRefs.env.N8N_ENCRYPTION_KEY_FILE`. |
| `N8N_RUNNERS_AUTH_TOKEN` | With task runners enabled. See [Task runners](#task-runners). |
| `N8N_HOST`, `N8N_PORT`, `N8N_PROTOCOL` | Never. The Secret still renders with them, but n8n no longer receives their values. Delete them once `editor.url` is set. |

In 1.x, n8n built its public URLs from `N8N_HOST` and `N8N_PROTOCOL` when no `editor.url`, `webhook.url` or ingress host was set. If your install relies on that, set `editor.url` before you upgrade. Otherwise n8n builds its URLs from `localhost`, so the webhook and OAuth callback URLs it shows point at `localhost`.

If you set `license.activationKey` inline, the chart now stores it in the chart's Secret and the containers read it from there. You do not need to change anything.

### Environment variables

You now set environment variables as one flat map per component. The chart renders them into one ConfigMap per component, and each container loads its ConfigMaps with `envFrom`. Maps merge across values files, so an overlay file only needs the variables it changes.

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

Remove each list once its entries have moved, including empty lists. The render fails on any of these keys while it is set.

`env.shared` reaches every n8n process: main, workers and webhook processors. It does not reach the task runner sidecar. Use `env.taskRunner` for the sidecar.

Check these behaviour changes:

- **A variable the chart sets cannot go in an `env` map.** The render fails and names the values key that sets it. Set that key instead. To replace the chart's value on purpose, use `chartEnvOverrides.<component>`. The chart lists the overrides in effect after install. The migration script moves such a variable from your `extraEnv` lists to `chartEnvOverrides` where your value won in 1.x, and removes it where the chart's value won.
- **`envFrom` refs now win over the chart's ConfigMap values.** In 1.x the chart's variables took precedence over `config.extraEnvFrom`. In 2.0, `envFrom.shared` and `envFrom.<component>` load after the chart's ConfigMaps, so a key in them replaces the chart's value. Variables the chart reads from a Secret, such as the encryption key and database password, are in the container's `env` list and still win. Check that the ConfigMaps and Secrets you load hold only the keys you mean to set.
- **`webhook.timeout` is removed.** n8n never read the variable it set, so it had no effect. Remove it from your values.

### Worker concurrency

`executions.concurrency.productionLimit` is removed. Set `N8N_CONCURRENCY_PRODUCTION_LIMIT` in an `env` map instead.

| If your values set | Do this |
|---|---|
| `productionLimit` other than -1, in queue mode | Set `env.worker.N8N_CONCURRENCY_PRODUCTION_LIMIT` to the same number. Remove `queueMode.workerConcurrency` if you set it. |
| `productionLimit` other than -1, in standalone mode | Set `env.main.N8N_CONCURRENCY_PRODUCTION_LIMIT` to the same number. |
| `productionLimit: -1` | Remove it. -1 is n8n's default. |

```yaml
# 1.x
executions:
  concurrency:
    productionLimit: 50

# 2.0, queue mode
env:
  worker:
    N8N_CONCURRENCY_PRODUCTION_LIMIT: 50
```

When the variable is set in queue mode, n8n uses it as each worker's concurrency and ignores `queueMode.workerConcurrency`. The render fails if a worker gets both, from `env.shared` or `env.worker`.

`queueMode.workerConcurrency` is now empty by default, so workers start without a `--concurrency` flag and use n8n's default of 10.

### Worker probes

A worker probe is now HTTP against the worker health endpoint, or an exec probe that runs the `command` you set.

| If your values set | Do this |
|---|---|
| `probes.worker.liveness.type` or `probes.worker.readiness.type` | Remove it. Set `command` on the probe for an exec probe, or leave `command` empty to probe the health endpoint. The render fails until you do. |
| `command: ["/bin/sh", "-c", "pgrep -f 'n8n worker' > /dev/null"]` on a worker probe | Remove it. This check always passes, because `pgrep` matches its own shell. The chart does not detect it. |
| `redis.healthCheck.enabled: false` | Remove it to probe the health endpoint, which is the default. To keep it, set `command` on each enabled liveness or readiness probe, or set `enabled: false` on that probe. The startup probe needs nothing, because the chart leaves it out when the health endpoint is off. The render fails until you do. |

A values file copied whole from chart 1.16 or earlier sets all three. Remove all three, and the workers use the health endpoint.

### Task runners

With n8n 3.0, task runners are on by default. In queue mode, each worker pod gains a `task-runner` container that requests 100m CPU and 128Mi of memory, with a 512Mi memory limit. In standalone mode, the main pod gains it instead. Plan node capacity for the extra requests, or adjust them under `taskRunners.resources`. To keep code running inside the n8n process, set `taskRunners.enabled: false`.

With task runners enabled, the runner and the broker need a shared auth token. The chart reads it from the core Secret under the key `N8N_RUNNERS_AUTH_TOKEN`, and never generates it.

- If you set `secretRefs.existingSecret`, add the token to that Secret. For example:

  ```bash
  kubectl patch secret n8n-core-secrets --type merge --patch-file /dev/stdin <<EOF
  {"stringData":{"N8N_RUNNERS_AUTH_TOKEN":"$(openssl rand -base64 32)"}}
  EOF
  ```

  The chart cannot see into that Secret. If the key is missing, the pods do not start, and their events name the key.
- If the chart manages the core Secret, set `secretRefs.env.N8N_RUNNERS_AUTH_TOKEN` next to `secretRefs.env.N8N_ENCRYPTION_KEY`. The render fails until you do.
- If you set `taskRunners.authToken.existingSecret`, there is nothing to do.
- If you set `taskRunners.authToken.value`, remove it. Then supply the token as the two bullets above describe: in the Secret named in `secretRefs.existingSecret`, or in `secretRefs.env.N8N_RUNNERS_AUTH_TOKEN`. The render fails on the old key and names both places.

A new token works straight away. The runner and the broker share a pod, and every pod restarts on upgrade, so you do not need to keep the token the 1.x chart generated.

The chart does not render a separate task-runner Secret, so Helm removes the one ending in `-task-runners` on upgrade. Do not name that Secret in `taskRunners.authToken.existingSecret`.

Remove `taskRunners.nativePythonRunner` from your values. The render fails while it is set. The task runner image decides whether Python runs, and the default `n8nio/runners` image runs both JavaScript and Python. n8n no longer reads the variable the key set.

The task broker now listens on localhost only, which is n8n's default. The runner sidecar reaches it there, so the default setup needs no change. Remove `taskRunners.broker.listenAddress` from your values. The render fails while it is set. If you run a runner outside the pod, set `N8N_RUNNERS_BROKER_LISTEN_ADDRESS` in `env.worker`, or in `env.main` in standalone mode.

### Binary data and S3

With `s3.enabled: true`, n8n now stores binary data in the S3 bucket. In 1.x the chart set the mode to `filesystem`, so n8n wrote binary data to each pod's local disk and the bucket held no binary data.

S3 binary data storage needs an n8n Business or Enterprise licence. Without one, n8n exits at boot, so the chart now requires `license.enabled: true` alongside `s3.enabled: true`. If your install has no such licence, set `s3.enabled: false` before you upgrade.

| If your values set | Do this |
|---|---|
| `s3.storage.mode` | Remove the line. `s3.enabled` sets the mode. The render fails until you do. |
| `s3.enabled: true` without `license.enabled: true` | Set `license.enabled: true` with your licence key, or alone if the licence reaches n8n another way. The render fails until you do. |
| `N8N_DEFAULT_BINARY_DATA_MODE: filesystem` in queue mode | Remove it, and n8n uses `database`. Or set `s3.enabled: true`. The render fails until you do. |
| `N8N_DEFAULT_BINARY_DATA_MODE` with `s3.enabled: true`, to keep binary data out of the bucket | Move it to `chartEnvOverrides.shared`. |

n8n keeps reading the binary data it stored on disk before the upgrade, as long as the volume that holds it is still mounted. With `persistence.enabled: true`, files from earlier executions on main stay readable. Files on a worker, or on main without persistence, were already lost each time the pod restarted.

### Ingress and cloud integration

This section covers public URLs, the webhook Ingress, client IP addresses, and controller and cloud annotations.

#### Public URLs

The chart now sets the webhook URL from the hosts it routes webhooks on. Webhooks share the editor's address unless you give them hosts of their own, under `ingress.webhook.hosts` or `httpRoute.webhook.hostnames`. In 1.x, plain-HTTP installs got `https://` webhook URLs, installs with `editor.url` but no ingress got `http://localhost:5678`, and the chart could not route webhooks on a separate host.

| If your values set | What changes | Do this |
|---|---|---|
| `editor.url` with `http://` and an ingress, without `webhook.url` | Webhook URLs move from `https://` to `http://`, matching the editor. | Nothing, unless webhooks must stay on `https://`. Then set `webhook.url`. |
| `editor.url` on a different host from the ingress, without `webhook.url` | Webhook URLs move to the `editor.url` host. | Nothing, unless webhooks must stay on the ingress host. Then set `webhook.url` to it. |
| `editor.url` with no ingress, without `webhook.url` | n8n gets a webhook URL. In 1.x it showed `http://localhost:5678`. | Nothing. |
| `webhook.url` with no ingress, without `editor.url` | Nothing. n8n uses the webhook URL as the editor URL, as the chart did in 1.x. | Nothing, or set `editor.url` to make it explicit. |
| `webhook.url` set to the same address as `editor.url`, or to the ingress host with no `editor.url` | Nothing. | Remove `webhook.url`. It now repeats the default. |
| `webhook.url` on a separate host, with your own Ingress or route for it | Nothing. | Optionally, move the host to `ingress.webhook.hosts` or `httpRoute.webhook.hostnames`, remove your own Ingress or route, and remove `webhook.url`. |
| `editor.url`, and `N8N_WEBHOOK_URL` in `env`, without `webhook.url` | The render fails, because the chart now sets `N8N_WEBHOOK_URL` from `editor.url`. | Move the address to `webhook.url`. |

#### The webhook Ingress

| If your values set | What changes | Do this |
|---|---|---|
| Any `ingress.webhookProcessor` key | The render fails and names `ingress.webhook`. | Move `className`, `annotations` and `tls` to `ingress.webhook`, and remove `enabled`. An empty `ingress.webhook.className` now uses `ingress.className`, so set it to keep another class. The Ingress keeps its name. |
| `webhookProcessor.enabled` and `ingress.enabled`, with `ingress.webhookProcessor.enabled` false or unset | The chart now renders the webhook Ingress, which sends the production webhook paths to the webhook processors. In 1.x they reached main. | Nothing on ingress-nginx and other controllers that merge Ingresses for the same host. A controller that gives each Ingress its own load balancer, such as the AWS Load Balancer Controller, now creates a second one. To share one, put the same group annotation, for example `alb.ingress.kubernetes.io/group.name`, in `ingress.annotations` and `ingress.webhook.annotations`. |

#### Client IP addresses

With an Ingress or an HTTPRoute, the chart now sets `N8N_PROXY_HOPS` to `1` on main and the webhook processors. n8n records and checks the client's IP address, which it reads from `X-Forwarded-For`, rather than the ingress controller's or Gateway's. This applies to IP allowlists on Webhook nodes and the addresses n8n logs.

| If your values set | What changes | Do this |
|---|---|---|
| `ingress.enabled` or `httpRoute.enabled`, with nothing in front of the ingress controller or Gateway | n8n sees each client's IP address. In 1.x every request came from the proxy pod's address. | Check any Webhook node IP allowlist that lists the proxy's address. |
| `ingress.enabled` or `httpRoute.enabled`, behind another proxy such as a CDN or a cloud load balancer that adds its own hop | n8n takes the address that proxy added, not the client's. | Set `chartEnvOverrides.shared.N8N_PROXY_HOPS` to the number of proxies in front of n8n, for example `2`. |
| `N8N_PROXY_HOPS` in `env.shared`, `env.main` or `env.webhookProcessor`, with `ingress.enabled` or `httpRoute.enabled` | The render fails, because the chart now sets it on main and the webhook processors. | Move it to `chartEnvOverrides`, under the same component. `env.worker` can keep it. |

n8n now takes the client address from `X-Forwarded-For`, which a caller that reaches the pods directly can set. If you rely on the client address, for example in a Webhook node IP allowlist, allow only the ingress controller or Gateway, and the release's own pods, to reach the n8n pods. See [Client IP addresses](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/README.md#client-ip-addresses) in the README for a `networkPolicy.ingress` example.

#### Controller and cloud annotations

The chart no longer sets annotations for a specific ingress controller or cloud. Set them yourself in `ingress.annotations` and `serviceAccount.annotations`. The examples show them for ingress-nginx and EKS.

| If your values set | What changes | Do this |
|---|---|---|
| Any `ingress.sticky` key | The render fails and names `ingress.annotations`. | Remove `ingress.sticky`. On ingress-nginx, copy the four `nginx.ingress.kubernetes.io/` cookie annotations from [https-ingress.yaml](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/examples/https-ingress.yaml) into `ingress.annotations`. If you changed `cookieName`, `cookieExpires` or `cookieMaxAge`, put your values in `session-cookie-name`, `session-cookie-expires` and `session-cookie-max-age`. |
| `serviceAccount.awsRoleArn` | The render fails and names `serviceAccount.annotations`. | Remove it, and set `eks.amazonaws.com/role-arn` to the same role in `serviceAccount.annotations`. If you already set that annotation, only remove the key. With `serviceAccount.create: false`, the chart does not manage the ServiceAccount, so annotate the existing one directly. |
| `s3.auth.autoDetect: true` without `serviceAccount.awsRoleArn` | The render no longer fails. | Nothing. EKS Pod Identity and other credential sources work without a role annotation. |

### Security contexts

The chart-wide `securityContext` block is retired. `podSecurityContext` and `containerSecurityContext` each have a `shared` block that applies to every pod or container. Each role block merges over `shared` field by field, and the role wins. Set a field to `null` to remove it.

| If your values set | Do this |
|---|---|
| `securityContext.fsGroup` | Move it to `podSecurityContext.shared.fsGroup`. |
| `securityContext.runAsUser` | Move it to `podSecurityContext.shared.runAsUser`. |
| `securityContext.runAsGroup` | Move it to `podSecurityContext.shared.runAsGroup`. |
| `securityContext.enabled: true` | Remove it. The defaults apply without it. |
| `securityContext.enabled: false` | Set `podSecurityContext.shared: null`. |
| A `podSecurityContext.<role>` block that leaves out a field to remove it | Set that field to `null` in the block. The block now merges over `shared` instead of replacing it, and the render does not detect this. |

`runAsNonRoot: true` and the `RuntimeDefault` seccomp profile are now in `podSecurityContext.shared` too, so you can change or remove them. The container defaults are in `containerSecurityContext.shared`. A `containerSecurityContext.<role>` override from 1.x keeps working, because it now merges over `shared`.

The migration script sets the nulls in `podSecurityContext.<role>` blocks for you, so each pod keeps its 1.x security context. It does this only when your values file also sets a retired key, because a file without one is valid for 2.0 as it stands. Remove the nulls to take the 2.0 defaults.

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

The NetworkPolicy now renders `networkPolicy.ingress` and `networkPolicy.egress`. In 1.x the chart ignored both. A list you set replaces the chart's rules for that direction and does not merge with them.

If you leave `networkPolicy.egress` empty, the policy now allows all egress. In 1.x it allowed only DNS, the database port, the Redis port and 443. To keep the 1.x rules, set them as your egress list. Change the ports if you changed `database.port` or `redis.port`:

```yaml
networkPolicy:
  egress:
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    - ports:
        - protocol: TCP
          port: 5432   # database.port
    - ports:
        - protocol: TCP
          port: 6379   # redis.port, queue mode only
    - ports:
        - protocol: TCP
          port: 443
```

If you leave `networkPolicy.ingress` empty, nothing changes. The policy allows the release's own pods and any source on `service.port`.

If your values set a non-empty list, check it before you upgrade. Those rules now take effect, and they are the only rules for that direction. An egress list must allow DNS, the database and every system your workflows call. In queue mode it must also allow Redis, and with S3 enabled it must allow your S3 endpoint. An ingress list must allow your ingress controller. It must also allow any in-cluster client that calls n8n, such as the `helm test` pod.

### Persistence

With `persistence.enabled: true` and only `ReadWriteOnce` or `ReadWriteOncePod` access modes, the main Deployment now uses the `Recreate` strategy. The old main pod stops before the new one starts, so each upgrade has a short outage, and the rollout no longer waits on a volume the old pod still holds. To keep rolling updates, set `strategy.type: RollingUpdate`. A `strategy` you set is used as it is.

With `persistence.existingClaim`, remove `persistence.size` and `persistence.storageClassName` from your values. The chart does not create a PVC when you supply one, so those keys did nothing, and the render now fails on them. Keep `persistence.accessModes`, and set it to match your claim.

If you installed the 1.x release with Helm 4, the first upgrade can fail with `spec.strategy.rollingUpdate: Forbidden: may not be specified when strategy type is 'Recreate'`. Helm 4 applies changes on the server by default, and that leaves the `rollingUpdate` settings Kubernetes added to the 1.x Deployment. Run that upgrade once with `--server-side=false`. Later upgrades do not need it. Releases installed with Helm 3 upgrade without it.

### Pod defaults

The pods now get only what n8n uses. n8n reads none of the settings below. If a container you add with `extraContainers` or `extraInitContainers` needs one, set it back.

| What changes | To keep the 1.x behaviour, set |
|---|---|
| `enableServiceLinks` is new and `false`, so Kubernetes no longer adds `<SERVICE>_SERVICE_HOST`, `<SERVICE>_PORT` and related variables to n8n's pods for each Service in the namespace. | `enableServiceLinks: true` |
| `rbac.create` is now `false`, so the chart no longer creates a Role that reads ConfigMaps and Secrets, or its RoleBinding. Helm removes both on upgrade. | `rbac.create: true` |
| `serviceAccount.automountServiceAccountToken` is now `false`, so n8n's pods no longer get a Kubernetes API token at `/var/run/secrets/kubernetes.io/serviceaccount`. | `serviceAccount.automountServiceAccountToken: true` |

### n8n 3.0

Chart 2.0.0 runs n8n 3.0. Step 1 of [Upgrade steps](#upgrade-steps) covers n8n's own breaking changes and the Migration Report. This section covers the changes you can handle in your chart values.

#### Changed defaults in n8n 3.0

The chart does not set these, so n8n's new defaults apply as soon as the chart runs n8n 3.0. Workflows with long-running Code nodes or large archives are the most likely to be affected.

| What changes in n8n 3.0 | To keep the n8n 2.x behaviour, set |
|---|---|
| A JavaScript Code node task times out after 60 seconds, down from 300. | `N8N_RUNNERS_TASK_TIMEOUT: 300` in both `env.shared` and `env.taskRunner`. n8n and the runner each apply the limit. Python tasks, which stopped at 60 seconds in n8n 2.x, then also get 300. |
| The Compression node stops at 256 MiB of decompressed data, down from 2 GiB. | `N8N_COMPRESSION_NODE_MAX_DECOMPRESSED_SIZE_BYTES: 2147483648` in `env.shared` |
| The Compression node stops at 1,000 entries in an archive, down from 5,000. | `N8N_COMPRESSION_NODE_MAX_ZIP_ENTRIES: 5000` in `env.shared` |
| n8n does not install or load community packages that n8n has not verified. Unverified packages you already installed stop loading. | `N8N_UNVERIFIED_PACKAGES_ENABLED: true` in `env.shared` |
| n8n enforces its Content-Security-Policy. n8n 2.x only reported violations. | `N8N_CONTENT_SECURITY_POLICY: "{}"` and `N8N_CONTENT_SECURITY_POLICY_REPORT_ONLY: default` in `env.shared` |
| Chat Hub is off. | Add `chat-hub` to `N8N_ENABLED_MODULES` in `env.shared`. Do not also list it in `N8N_DISABLED_MODULES`, or n8n fails at startup. n8n 4 removes Chat Hub. |

You can set these before the chart moves to n8n 3.0. n8n 2.45 and later 2.x versions read each of them, so the behaviour does not change at the upgrade.

If you set `N8N_COMMUNITY_PACKAGES_MANAGED_BY_ENV: true`, an unverified package in `N8N_COMMUNITY_PACKAGES` stops main from starting. Set `N8N_UNVERIFIED_PACKAGES_ENABLED: true`, or remove the package from the list.

With the Content-Security-Policy enforced, scripts that do not carry n8n's nonce stop running. This includes snippets that an ingress controller or a CDN adds to the page. If yours adds one, keep the 2.x behaviour with the lines in the table, or stop adding the snippet.

SSRF protection is off by default. If you set `N8N_SSRF_PROTECTION_ENABLED: true`, the `default` block list in n8n 3.0 also blocks `100.64.0.0/10`, `::/128`, `2002::/16` and `64:ff9b::/96`. Requests to hosts in these ranges fail. Some pod networks use `100.64.0.0/10`. If your workflows call services in one of these ranges, add the range to `N8N_SSRF_ALLOWED_IP_RANGES`.

#### Encryption key rotation

n8n 3.0 turns on encryption key rotation. On its first start, main creates a data key in the database. If its database user cannot create the key, main exits.

#### Removed variables

n8n 3.0 no longer reads these variables. It logs a warning at startup for each one you still set, except where the table says otherwise. The chart does not check for them. The migration script removes or renames them in your values file. Remove any you set elsewhere, such as in a ConfigMap you load with `envFrom`.

| Variable | What to do |
|---|---|
| `N8N_DB_PING_TIMEOUT` | Set `DB_PING_TIMEOUT_MS` instead. |
| `N8N_WORKFLOW_TAGS_DISABLED` | Remove it. Workflow tags are always on. |
| `N8N_PRE_EXECUTE_ERROR_CREATES_EXECUTION` | Remove it. Nothing replaces it. |
| `N8N_RUNNERS_ENABLED` | Remove it. Nothing replaces it. |
| `N8N_MIGRATE_FS_STORAGE_PATH` | Remove it. The storage directory rename always runs. n8n logs no warning. |
| `N8N_DEFAULT_BINARY_DATA_MODE: default` | Remove it, or set another mode. n8n 3.0 has no in-memory mode, and falls back to `filesystem`, or to `database` in queue mode. |
| `N8N_AGENTS_SKILLS_HUB_ENABLED`, `N8N_ENV_FEAT_CRED_SHARING` | Remove them. n8n 2.46 removed them, and both features are always on. |
| `N8N_INSTANCE_AI_LOCAL_GATEWAY_DISABLED`, `N8N_INSTANCE_AI_GATEWAY_API_KEY` | Remove them. n8n 2.46 removed them with the local gateway. n8n logs no warning. |

The chart no longer sets `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS`. In queue mode, n8n 3.0 always runs manual executions on workers. If you set the variable in `chartEnvOverrides`, the render fails. Remove it there and from your `env` maps, because n8n 3.0 logs a warning while it is set.

The chart sets `N8N_RUNNERS_MODE: external` on main and the webhook processors in queue mode, so they log no internal-mode warning. If you set `N8N_RUNNERS_MODE` in `env.shared` or `env.main` in queue mode, or in `env.webhookProcessor` with webhook processors enabled, the render fails. Move it to `chartEnvOverrides` for the same component. See [decision 0031](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0031-queue-mode-main-and-webhook-run-external-runner-mode.md).

#### Image changes

The n8n image no longer includes GraphicsMagick. If a derived image or an Execute Command node calls `gm`, install it in your own image. The base image has no `apk-tools`, so you cannot add it with `apk` in a later layer.

If you mount your own `n8n-task-runners.json` through `taskRunners.customConfig`, add `--no-experimental-webstorage` to the JavaScript runner's arguments. A file copied from n8n 2.x does not have it.

#### Storage directory

On its first start, n8n 3.0 renames `/home/node/.n8n/binaryData` to `/home/node/.n8n/storage`. The chart mounts the whole of `/home/node/.n8n`, so the rename needs no change to your values.

If both directories exist, n8n does not start. A chart install does not normally create both. The n8n Migration Report flags this as "Both storage directories exist" and provides guidance on how to fix it.

### Check the upgrade

After `helm upgrade`, check that:

- Every pod is Ready, and `helm test <release>` passes.
- The webhook URL a Webhook node shows uses your public address, not `localhost`. The same goes for OAuth callback URLs.
- A workflow with a Code node runs. This checks the task runner and its token.

### Roll back

`helm rollback` restores the 1.x manifests, but not the database. n8n 3.0 changes the database on its first start, and n8n 2.x cannot run against it. To go back to chart 1.x:

1. Scale every n8n Deployment to 0.
2. Restore the database backup you took in step 2 of [Upgrade steps](#upgrade-steps).
3. Run `helm rollback <release>`.
