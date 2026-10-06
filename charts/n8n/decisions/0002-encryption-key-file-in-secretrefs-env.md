# 0002. The encryption key file path lives in `secretRefs.env`

Date: 2026-10-06
PR: https://github.com/n8n-io/n8n-hosting/pull/183

## Context

Some installs can't keep n8n's encryption key in a Kubernetes Secret. Instead they mount it as a file, for example through the Secrets Store CSI driver. n8n supports this through `N8N_ENCRYPTION_KEY_FILE`. However, n8n reads `N8N_ENCRYPTION_KEY` first and only reads the file when that variable is absent. The chart always set `N8N_ENCRYPTION_KEY`, so the file form couldn't be used.

The chart needed a switch, and it needed a place in values for that switch. `secretRefs.env` already holds the encryption key, but it does two jobs. It is where users set values, and the chart writes its keys into the chart-managed Secret. A file path is not a secret, so it doesn't belong in that Secret.

## Decision

Setting `secretRefs.env.N8N_ENCRYPTION_KEY_FILE` to an absolute path switches on file mode. In file mode, the main, worker and webhook-processor containers receive `N8N_ENCRYPTION_KEY_FILE` and never receive `N8N_ENCRYPTION_KEY`. The chart-managed Secret never contains `N8N_ENCRYPTION_KEY_FILE`, and in file mode it doesn't contain `N8N_ENCRYPTION_KEY` either. A relative path fails the render.

We considered a dedicated `encryptionKey` block for chart 1.x and rejected it. The 2.0 env model moves every key in `secretRefs.env`, so a separate block now would mean two migrations for the same setting. Keeping the switch next to the key follows *One place to set anything*: each encryption-key setting has a single home until 2.0 gives them a new one.

## Consequences

- File mode needs no new volume values. The user mounts the file with the existing `extraVolumes` and `extraVolumeMounts`.
- When `secretRefs.existingSecret` is set, the chart can't see inside that Secret. The mode comes from values alone.
- Switching an existing install between env and file mode must keep the same key value. Otherwise n8n can no longer decrypt stored credentials.
- `secrets.yaml` treats this one key in `secretRefs.env` as a special case. That special case goes away when 2.0 replaces the map.
