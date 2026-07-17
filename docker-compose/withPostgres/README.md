# n8n with PostgreSQL

Starts n8n with PostgreSQL as database.

## Start

To start n8n with PostgreSQL simply start docker-compose by executing the following
command in the current folder.

**IMPORTANT:** But before you do that change the default users and passwords in the [`.env`](.env) file!

```
docker compose up -d
```

To stop it execute:

```
docker compose stop
```

## Configuration

The default name of the database, user and password for PostgreSQL can be changed in the [`.env`](.env) file in the current directory.

## AI Assistant (optional)

n8n's AI Assistant (the `instance-ai` module) runs generated code in an isolated sandbox. This example ships the sandbox services (`sandbox-certs`, `sandbox-api`, `sandbox-runner-1`) behind a Compose profile, so they're off by default and a plain `docker compose up -d` is unaffected.

To enable it:

1. Uncomment the **AI Assistant** block in [`.env`](.env) and set real values — your model API key and unique sandbox secrets (don't leave the `change-me-…` placeholders). `N8N_INSTANCE_AI_SANDBOX_API_KEY` must match one of the values in `SANDBOX_API_KEYS`.
2. Start with the profile enabled:

   ```
   docker compose --profile ai-assistant up -d
   ```

> **Enable both together.** The `.env` values and the `--profile ai-assistant` flag are independent switches. If you fill in `.env` but start without the profile, n8n loads the Assistant while the sandbox services stay down, so Assistant requests fail until you restart with `--profile ai-assistant`.

`sandbox-certs` runs once to bootstrap the mTLS certificates the other services share, then exits; `sandbox-api` and `sandbox-runner-1` start after it. Once `sandbox-api` is healthy the runner registers itself and n8n can reach the sandbox. Open n8n at `http://localhost:5678`.

### Security checklist

- **`sandbox-runner-1` runs privileged Docker-in-Docker — treat it as equivalent to root on the host.** Never expose it (or `sandbox-api`) to the public internet; only n8n's `5678` should be internet-facing. The sandbox services talk to each other over the internal Compose network by service name.
- Set `SANDBOX_API_KEYS`, the registration token, and the runner key to unique values, and rotate them periodically.
- Have a plan to regenerate the `sandbox-tls` volume — the certificates `sandbox-certs` generates don't auto-renew.
- The `sandbox-api` healthcheck assumes `wget` exists in the image. If it doesn't, swap it for `curl` or a TCP check — run `docker compose run sandbox-api which wget` to check first.
