# n8n with PostgreSQL and Worker

Starts n8n with PostgreSQL as database, Redis for queue management, and a Worker as a separate container. Task runner sidecar containers are included for executing Code nodes (JavaScript/Python), as required by n8n 2.0+.

## Start

To start n8n simply start docker-compose by executing the following
command in the current folder.

**IMPORTANT:** But before you do that change the default users, passwords, and tokens in the [`.env`](.env) file!

```
docker compose up -d
```

To stop it execute:

```
docker compose stop
```

## Configuration

The default name of the database, user and password for PostgreSQL can be changed in the [`.env`](.env) file in the current directory.

The `RUNNERS_AUTH_TOKEN` in the [`.env`](.env) file is a shared secret used for authentication between n8n and the task runner containers. Generate a secure random value for production use.

## Upgrade Considerations

### PostgreSQL 18

This example runs `postgres:18`.

The compose file pins `PGDATA` to `/var/lib/postgresql/data`. Postgres 18 changed where it stores
data by default, and pinning it keeps the volume mount stable across major versions. Don't remove
that line, or the database will start empty on an existing volume.

### Installing fresh

Nothing to do. Run `docker compose up -d`.

### Upgrading an existing setup

This is a major version upgrade and it is breaking. Postgres 18 cannot read a data directory written
by 16, so bumping the image alone stops with:

```
FATAL:  database files are incompatible with server
```

Nothing is deleted, and you can pin the image back to `postgres:16` at any point.

Follow the official guide,
[Upgrading a PostgreSQL Cluster](https://www.postgresql.org/docs/18/upgrading.html). Pick a method
based on your database size and how much downtime you can take.

For a small setup, dump and restore is usually simplest. n8n is offline while you do it:

```bash
# 0. Load .env into your shell. Compose reads it, your shell does not
set -a && . ./.env && set +a

# 1. Export, with your old setup still running
docker compose exec -T postgres pg_dumpall -U "$POSTGRES_USER" > n8n-backup.sql

# 2. Check the export worked. This must print 1
grep -c "PostgreSQL database cluster dump complete" n8n-backup.sql

# 3. Stop, and delete ONLY the database volume. The guard repeats the check, so a
#    failed export stops here instead of falling through to the delete
grep -q "PostgreSQL database cluster dump complete" n8n-backup.sql \
  && docker compose down \
  && docker volume rm withpostgresandworker_db_storage

# 4. Start ONLY the database and import into it. Bringing the whole stack up here
#    lets n8n build its schema first, and the import then collides with it
docker compose up -d postgres
docker compose exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < n8n-backup.sql

# 5. Import done, now start the rest
docker compose up -d
```

### Gotchas

Things the PostgreSQL guide will not tell you, because they are specific to this setup.

- **Never use `docker compose down -v` here.** That also deletes `n8n_storage`, which holds n8n's
  local state. Keep your `.env` too: this example sets `N8N_ENCRYPTION_KEY` from it, and without
  that key your saved credentials cannot be decrypted, even with the database restored. Delete only `withpostgresandworker_db_storage`.
- **`role "..." already exists` and `database "..." already exists` on import are expected.** The
  container creates both on first start. Your data still imports.
- **Staying on 16 is fine.** It is still supported. Pin the image back to `postgres:16`.
