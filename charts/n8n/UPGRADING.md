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

Pass your values file with `-f`. Do not use `--reuse-values`. It keeps the defaults of the chart version you installed as well as your own values, so the 2.0 render fails on 1.x defaults that 2.0 no longer reads. If you no longer have your values file, `helm get values <release> -o yaml` prints the values you set. `--reset-then-reuse-values`, in Helm 3.14 or later, reuses your values with the new chart's defaults, and also works.

### Values validation

The schema rejects any values key it does not know, so a typo or a key from another chart fails the install or upgrade instead of being ignored. Helm checks the schema before it renders, and names each key and where it sits:

```
- at '/queueMode': additional properties 'workerReplicas' not allowed
```

Remove each key the error names, or correct its spelling against [values.yaml](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/values.yaml). Free-form blocks still accept any key: annotations, labels, `nodeSelector`, `tolerations`, `affinity`, `resources`, `strategy`, `dnsConfig` and the `extra*` lists. If you keep your own top-level keys, for YAML anchors or for values your `extraObjects` read through `tpl`, move them under `global`. To skip the schema check for one release, Helm 3.16 and later take `--skip-schema-validation`. The chart's own checks still run. See [decision 0016](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0016-values-schema-rejects-unknown-keys.md).

If your values file sets a key the chart no longer reads, the render fails. The message names each such key and what replaces it, all in one render. The chart stops rather than ignoring the key, so a setting cannot quietly stop working. See [decision 0020](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0020-retired-values-keys-fail-the-render.md).

### Database

`database.type` alone chooses the database: `postgresdb`, the default, or `sqlite`. See [decision 0018](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0018-database-type-replaces-useexternal.md).

| If your values set | Do this |
|---|---|
| `database.useExternal` | Remove it. Leave `database.type` as it is. |
| `redis.useExternal` | Remove it. Nothing replaces it. Queue mode connects to the Redis at `redis.host`. |
| `redis.worker.maxStalledCount` | Remove it. n8n 2.0 removed the setting, so it had no effect. |

If your values set `database.type: sqlite` without `useExternal`, the chart stops passing PostgreSQL settings to n8n. n8n did not use them with SQLite. The pods restart once on upgrade.

The chart never read `database.ssl.key`, and setting it now fails the render. Put the client key in a Secret, and set `database.ssl.existingSecret.name` and `database.ssl.existingSecret.keyKey`. See [decision 0002](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0002-postgres-tls-material-from-an-existing-secret.md).

### Secrets and host settings

The chart's Secret holds only secrets. Host, port and protocol are no longer read from it. See [decision 0012](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0012-env-as-per-component-maps.md).

| If your values set | Do this |
|---|---|
| `secretRefs.env.N8N_HOST` or `secretRefs.env.N8N_PROTOCOL` | Remove them. n8n builds its public URLs from `editor.url` and `webhook.url`. If you still need either variable, set it in `env.shared`. |
| `secretRefs.env.N8N_PORT` | Remove it. The chart sets `N8N_PORT` from `service.port` on every n8n process, workers included. |

If you use `secretRefs.existingSecret`, the Secret needs the `N8N_ENCRYPTION_KEY` key, unless you set `secretRefs.env.N8N_ENCRYPTION_KEY_FILE`. With task runners enabled, it also needs `N8N_RUNNERS_AUTH_TOKEN`; see [Task runners](#task-runners). The chart reads those keys by name and ignores the rest of the Secret. A Secret that still holds `N8N_HOST`, `N8N_PORT` and `N8N_PROTOCOL` still renders, but n8n no longer receives those values.

In 1.x, n8n built its public URLs from `N8N_HOST` and `N8N_PROTOCOL` when no `editor.url`, `webhook.url` or ingress host was set. If your install relies on that, set `editor.url` before you upgrade. Otherwise n8n builds its URLs from `localhost`, so the webhook and OAuth callback URLs it shows point at `localhost`. After that, you can delete the three keys from the Secret.

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

Task runners are on by default. In queue mode, each worker pod gains a `task-runner` container that requests 100m CPU and 128Mi of memory. In standalone mode, the main pod gains it instead. Plan node capacity for the extra requests, or adjust them under `taskRunners.resources`. To keep code running inside the n8n process, set `taskRunners.enabled: false`. See [decision 0014](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0014-task-runners-on-by-default.md).

With task runners enabled, the runner and the broker need a shared auth token. The chart reads it from the core Secret under the key `N8N_RUNNERS_AUTH_TOKEN`, and never generates it. See [decision 0019](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0019-task-runner-token-in-the-core-secret.md).

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

The task broker now listens on localhost only, which is n8n's default. The runner sidecar reaches it there, so the default setup needs no change. Remove `taskRunners.broker.listenAddress` from your values. The render fails while it is set. If you run a runner outside the pod, set `N8N_RUNNERS_BROKER_LISTEN_ADDRESS` in `env.worker`, or in `env.main` in standalone mode. See [decision 0024](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0024-task-runner-broker-listens-on-localhost.md).

### Binary data and S3

With `s3.enabled: true`, n8n now stores binary data in the S3 bucket. In 1.x the chart set the mode to `filesystem`, so n8n wrote binary data to each pod's local disk and the bucket held no binary data. See [decision 0022](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0022-binary-data-mode.md).

S3 binary data storage needs an n8n Business or Enterprise licence. Without one, n8n exits at boot, so the chart now requires `license.enabled: true` alongside `s3.enabled: true`. If your install has no such licence, set `s3.enabled: false` before you upgrade.

| If your values set | Do this |
|---|---|
| `s3.storage.mode` | Remove the line. `s3.enabled` sets the mode. The render fails until you do. |
| `s3.enabled: true` without `license.enabled: true` | Set `license.enabled: true` with your licence key, or alone if the licence reaches n8n another way. The render fails until you do. |
| `N8N_DEFAULT_BINARY_DATA_MODE: filesystem` in queue mode | Remove it, and n8n uses `database`. Or set `s3.enabled: true`. The render fails until you do. |
| `N8N_DEFAULT_BINARY_DATA_MODE` with `s3.enabled: true`, to keep binary data out of the bucket | Move it to `chartEnvOverrides.shared`. |

n8n keeps reading the binary data it stored on disk before the upgrade, as long as the volume that holds it is still mounted. With `persistence.enabled: true`, files from earlier executions on main stay readable. Files on a worker, or on main without persistence, were already lost each time the pod restarted.

### Ingress and cloud integration

The chart now sets the webhook URL from the hosts it routes webhooks on. Webhooks share the editor's address unless you give them hosts of their own, under `ingress.webhook.hosts` or `httpRoute.webhook.hostnames`. In 1.x, plain-HTTP installs got `https://` webhook URLs, installs with `editor.url` but no ingress got `http://localhost:5678`, and the chart could not route webhooks on a separate host. See [decision 0023](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0023-editor-and-webhook-urls-follow-the-routed-hosts.md).

Public URLs:

| If your values set | What changes | Do this |
|---|---|---|
| `editor.url` with `http://` and an ingress, without `webhook.url` | Webhook URLs move from `https://` to `http://`, matching the editor. | Nothing, unless webhooks must stay on `https://`. Then set `webhook.url`. |
| `editor.url` on a different host from the ingress, without `webhook.url` | Webhook URLs move to the `editor.url` host. | Nothing, unless webhooks must stay on the ingress host. Then set `webhook.url` to it. |
| `editor.url` with no ingress, without `webhook.url` | n8n gets a webhook URL. In 1.x it showed `http://localhost:5678`. | Nothing. |
| `webhook.url` with no ingress, without `editor.url` | Nothing. n8n uses the webhook URL as the editor URL, as the chart did in 1.x. | Nothing, or set `editor.url` to make it explicit. |
| `webhook.url` set to the same address as `editor.url`, or to the ingress host with no `editor.url` | Nothing. | Remove `webhook.url`. It now repeats the default. |
| `webhook.url` on a separate host, with your own Ingress or route for it | Nothing. | Optionally, move the host to `ingress.webhook.hosts` or `httpRoute.webhook.hostnames`, remove your own Ingress or route, and remove `webhook.url`. |
| `editor.url`, and `N8N_WEBHOOK_URL` in `env`, without `webhook.url` | The render fails, because the chart now sets `N8N_WEBHOOK_URL` from `editor.url`. | Move the address to `webhook.url`. |

The webhook Ingress:

| If your values set | What changes | Do this |
|---|---|---|
| Any `ingress.webhookProcessor` key | The render fails and names `ingress.webhook`. | Move `className`, `annotations` and `tls` to `ingress.webhook`, and remove `enabled`. An empty `ingress.webhook.className` now uses `ingress.className`, so set it to keep another class. The Ingress keeps its name. |
| `webhookProcessor.enabled` and `ingress.enabled`, with `ingress.webhookProcessor.enabled` false or unset | The chart now renders the webhook Ingress, which sends the production webhook paths to the webhook processors. In 1.x they reached main. | Nothing on ingress-nginx and other controllers that merge Ingresses for the same host. A controller that gives each Ingress its own load balancer, such as the AWS Load Balancer Controller, now creates a second one. To share one, put the same group annotation, for example `alb.ingress.kubernetes.io/group.name`, in `ingress.annotations` and `ingress.webhook.annotations`. |

Client IP addresses:

With an Ingress or an HTTPRoute, the chart now sets `N8N_PROXY_HOPS` to `1` on main and the webhook processors. n8n records and checks the client's IP address, which it reads from `X-Forwarded-For`, rather than the ingress controller's or Gateway's. This applies to IP allowlists on Webhook nodes and the addresses n8n logs. See [decision 0028](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0028-n8n-trusts-the-proxy-the-chart-routes-through.md).

| If your values set | What changes | Do this |
|---|---|---|
| `ingress.enabled` or `httpRoute.enabled`, with nothing in front of the ingress controller or Gateway | n8n sees each client's IP address. In 1.x every request came from the proxy pod's address. | Check any Webhook node IP allowlist that lists the proxy's address. |
| `ingress.enabled` or `httpRoute.enabled`, behind another proxy such as a CDN or a cloud load balancer that adds its own hop | n8n takes the address that proxy added, not the client's. | Set `chartEnvOverrides.shared.N8N_PROXY_HOPS` to the number of proxies in front of n8n, for example `2`. |
| `N8N_PROXY_HOPS` in `env.shared`, `env.main` or `env.webhookProcessor`, with `ingress.enabled` or `httpRoute.enabled` | The render fails, because the chart now sets it on main and the webhook processors. | Move it to `chartEnvOverrides`, under the same component. `env.worker` can keep it. |

n8n now takes the client address from `X-Forwarded-For`, which a caller that reaches the pods directly can set. If you rely on the client address, for example in a Webhook node IP allowlist, allow only the ingress controller or Gateway, and the release's own pods, to reach the n8n pods. See [Client IP addresses](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/README.md#client-ip-addresses) in the README for a `networkPolicy.ingress` example.

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

The NetworkPolicy now renders `networkPolicy.ingress` and `networkPolicy.egress`. In 1.x the chart ignored both. A list you set replaces the chart's rules for that direction and does not merge with them. See [decision 0017](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0017-network-policy-allows-all-egress-by-default.md).

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

With `persistence.existingClaim`, remove `persistence.size` and `persistence.storageClassName` from your values. The chart does not create a PVC when you supply one, so those keys did nothing, and the render now fails on them. Keep `persistence.accessModes`, and set it to match your claim.

### Changed defaults

With `networkPolicy.enabled` and no `networkPolicy.egress` set, the NetworkPolicy now allows all egress. See [Network policy](#network-policy).

`queueMode.workerConcurrency` is now empty by default, so workers start without a `--concurrency` flag and use n8n's default of 10.

In queue mode, the render fails if you set `queueMode.workerConcurrency` together with `executions.concurrency.productionLimit`, or together with `N8N_CONCURRENCY_PRODUCTION_LIMIT` in `env.shared` or `env.worker`. n8n uses the production limit as each worker's concurrency and ignores the flag. To keep the concurrency your workers run at today, keep `productionLimit` and remove `workerConcurrency`.

`taskRunners.enabled` is now `true`. See [Task runners](#task-runners).

`taskRunners.resources.requests.memory` is now `128Mi`, down from `256Mi`. The limit stays `512Mi`.

`enableServiceLinks` is new and `false`, so Kubernetes no longer adds `<SERVICE>_SERVICE_HOST`, `<SERVICE>_PORT` and related variables to n8n's pods for each Service in the namespace. n8n reads none of them. If a container you add reads one of these variables, set `enableServiceLinks: true`. See [decision 0025](https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/decisions/0025-pods-get-only-what-n8n-uses.md).

With `persistence.enabled: true` and only `ReadWriteOnce` or `ReadWriteOncePod` access modes, the main Deployment now uses the `Recreate` strategy. The old main pod stops before the new one starts, so each upgrade has a short outage, and the rollout no longer waits on a volume the old pod still holds. To keep rolling updates, set `strategy.type: RollingUpdate`. A `strategy` you set is used as it is. With `persistence.existingClaim`, set `persistence.accessModes` to match your claim.

If you installed the 1.x release with Helm 4, the first upgrade can fail with `spec.strategy.rollingUpdate: Forbidden: may not be specified when strategy type is 'Recreate'`. Helm 4 applies changes on the server by default, and that leaves the `rollingUpdate` settings Kubernetes added to the 1.x Deployment. Run that upgrade once with `--server-side=false`. Later upgrades do not need it. Releases installed with Helm 3 upgrade without it.

`rbac.create` is now `false`, so the chart no longer creates a Role that reads ConfigMaps and Secrets, or its RoleBinding. n8n does not use them. Helm removes both on upgrade. If something else in your pods uses that Role, set `rbac.create: true`.

`serviceAccount.automountServiceAccountToken` is now `false`, so n8n's pods no longer get a Kubernetes API token at `/var/run/secrets/kubernetes.io/serviceaccount`. n8n does not call the Kubernetes API. If a container you add calls it, set `serviceAccount.automountServiceAccountToken: true`.

### n8n 3.0

Chart 2.0.0 runs n8n 3.0. Read [n8n's 3.0 breaking changes](https://docs.n8n.io/changelog/v30-breaking-changes/) before you upgrade. Then open the Migration Report in n8n, under **Settings > Migration Report**. It lists what in your instance needs to change. It needs n8n 2.39 or later, and the latest 2.x release has the newest checks.

This section covers the changes you can handle in your chart values, and some that n8n's page does not list.

#### Before you upgrade

Take a full backup of your database. The move to n8n 3.0 is one way. To go back to n8n 2.x, restore that backup.

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

n8n 3.0 turns on encryption key rotation. On its first start, main creates a data key in the database. If its database user cannot create the key, main exits. See [Before you upgrade](#before-you-upgrade).

#### Removed variables

n8n 3.0 no longer reads these variables. It logs a warning at startup for each one you still set, except where the table says otherwise. The chart does not check for them, so remove them from your `env` maps.

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

#### Image changes

The n8n image no longer includes GraphicsMagick. If a derived image or an Execute Command node calls `gm`, install it in your own image. The base image has no `apk-tools`, so you cannot add it with `apk` in a later layer.

If you mount your own `n8n-task-runners.json` through `taskRunners.customConfig`, add `--no-experimental-webstorage` to the JavaScript runner's arguments. A file copied from n8n 2.x does not have it.

#### Storage directory

On its first start, n8n 3.0 renames `/home/node/.n8n/binaryData` to `/home/node/.n8n/storage`. The chart mounts the whole of `/home/node/.n8n`, so the rename needs no change to your values. If both directories exist, n8n refuses to start and names them. Move the contents of `binaryData` into `storage`, remove `binaryData`, and start n8n again.
