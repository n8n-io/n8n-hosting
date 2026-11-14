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

## Upgrade Considerations

### n8n 3.0

`N8N_VERSION` in the [`.env`](.env) file pins the n8n version this example is tested with. The pin moves to n8n 3.x when 3.0 becomes n8n's stable release.

Before you upgrade:

* Read the [n8n 3.0 breaking changes](https://docs.n8n.io/changelog/v30-breaking-changes/).
* Open **Settings > Migration Report** in n8n. It lists what on your instance needs attention.
* Back up the `n8n_data` volume. It holds the SQLite database and the encryption key. n8n migrates its database forward when it starts, so the backup is your way back to 2.x.

To stay on n8n 2.x, keep `N8N_VERSION` at your current 2.x version when you take a newer copy of this folder.
