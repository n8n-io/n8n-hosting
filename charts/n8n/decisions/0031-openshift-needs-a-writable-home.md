# 0031. OpenShift gets a writable home in the example, not a chart default

Date: 2026-11-16
PR: https://github.com/n8n-io/n8n-hosting/pull/297

## Context

The restricted SCC assigns the UID and GID and rejects a pod that pins them. The chart's OpenShift recipe sets `fsGroup`, `runAsUser` and `runAsGroup` to `null`. That admits the pod. n8n still does not start. An assigned UID has no `/etc/passwd` entry, so `HOME` is `/` and n8n tries to create `/.n8n`. The image owns `/home/node` as uid 1000, so the assigned UID cannot create `/home/node/.cache`, or `/home/node/.n8n` on a worker or webhook processor. Main already mounts its data volume at `/home/node/.n8n`, which does not cover `.cache`.

## Decision

The chart does not add a volume or `N8N_USER_FOLDER` when the UID is null. Null is also how a user removes one field, and a volume at `/home/node` would hide a directory they mounted themselves. Under "Portable primitives with portable defaults" in `../DESIGN.md`, the OpenShift recipe stays in the example and in the docs that quote it. The recipe sets `N8N_USER_FOLDER` to `/home/node` and mounts an emptyDir there. Main's data volume stays at `/home/node/.n8n`.

## Consequences

A default install is unchanged. An OpenShift install that only nulls the IDs still fails until it adds the home directory. The example and the three copies of the recipe name both parts. A later image that makes `/home/node` writable by the root group can drop the emptyDir. `N8N_USER_FOLDER` stays, because `HOME` is still `/`.
