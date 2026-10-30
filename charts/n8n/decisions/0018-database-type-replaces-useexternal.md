# 0018. database.type alone chooses the database

Date: 2026-10-19
PR: https://github.com/n8n-io/n8n-hosting/pull/264

## Context

Chart 1.x had two database settings. `database.type` named the database n8n uses. `database.useExternal` chose between an external PostgreSQL and SQLite on a PersistentVolumeClaim. The name suggested a bundled database as the alternative, but the chart never shipped one. The schema only accepted `useExternal: false` together with `type: sqlite`, so the second setting repeated the first.

`redis.useExternal` was in `values.yaml`, but no template read it.

## Decision

`database.type` alone chooses the database. `postgresdb` connects n8n to your PostgreSQL. `sqlite` keeps the database on the PersistentVolumeClaim, in standalone mode only. This sits under "State is external and reached through a contract".

The values are the ones n8n reads from `DB_TYPE`, and the chart passes the value through unchanged. A chart-only name such as `postgres` would need a mapping, and it would differ from the n8n documentation.

`database.useExternal` and `redis.useExternal` are retired keys. The render fails on either one and says what to do instead. Queue mode connects to the Redis at `redis.host`, as before.

## Consequences

- Upgrading means deleting `useExternal`. `database.type` keeps the same values and the same default, so a values file that sets it needs no other change.
- An install that set `database.type: sqlite` and left `useExternal` at its default no longer gets the PostgreSQL settings. n8n ignored them with SQLite. Its pods restart once on upgrade.
- `sqlite` with queue mode or multi-main fails the render, as `useExternal: false` did.
- The database Secret contract can grow under `database` without another rename.
