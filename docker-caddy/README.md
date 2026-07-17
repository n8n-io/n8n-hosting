# n8n-docker-caddy

Get up and running with n8n on the following platforms:

* [DigitalOcean tutorial](https://docs.n8n.io/hosting/server-setups/digital-ocean/)
* [Hetzner Cloud tutorial](https://docs.n8n.io/hosting/server-setups/hetzner/)

If you have questions after trying the tutorials, check out the [forums](https://community.n8n.io/).

## Prerequisites

Self-hosting n8n requires technical knowledge, including:

* Setting up and configuring servers and containers
* Managing application resources and scaling
* Securing servers and applications
* Configuring n8n

n8n recommends self-hosting for expert users. Mistakes can lead to data loss, security issues, and downtime. If you aren't experienced at managing servers, n8n recommends [n8n Cloud](https://n8n.io/cloud/).

## AI Assistant (optional)

n8n's AI Assistant (the `instance-ai` module) runs generated code in an isolated sandbox. This setup ships the sandbox services (`sandbox-certs`, `sandbox-api`, `sandbox-runner-1`) behind a Compose profile, so they're off by default and a plain `docker compose up -d` is unaffected. The sandbox services are internal only — n8n (behind Caddy) stays the only externally reachable service.

To enable it:

1. Uncomment the **AI Assistant** block in [`.env`](.env) and set real values — your model API key and unique sandbox secrets (don't leave the `change-me-…` placeholders). `N8N_INSTANCE_AI_SANDBOX_API_KEY` must match one of the values in `SANDBOX_API_KEYS`.
2. Start with the profile enabled:

   ```
   docker compose --profile ai-assistant up -d
   ```

> **Enable both together.** The `.env` values and the `--profile ai-assistant` flag are independent switches. If you fill in `.env` but start without the profile, n8n loads the Assistant while the sandbox services stay down, so Assistant requests fail until you restart with `--profile ai-assistant`.

`sandbox-certs` runs once to bootstrap the mTLS certificates the other services share, then exits; `sandbox-api` and `sandbox-runner-1` start after it. Once `sandbox-api` is healthy the runner registers itself and n8n can reach the sandbox.

### Security checklist

- **`sandbox-runner-1` runs privileged Docker-in-Docker — treat it as equivalent to root on the host.** Never expose it (or `sandbox-api`) to the public internet; keep them internal and route only n8n through Caddy. The sandbox services talk to each other over the internal Compose network by service name.
- Set `SANDBOX_API_KEYS`, the registration token, and the runner key to unique values, and rotate them periodically.
- Have a plan to regenerate the `sandbox-tls` volume — the certificates `sandbox-certs` generates don't auto-renew.
- The `sandbox-api` healthcheck assumes `wget` exists in the image. If it doesn't, swap it for `curl` or a TCP check — run `docker compose run sandbox-api which wget` to check first.
