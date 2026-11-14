# n8n on Subfolder with SSL

Starts n8n and deploys it on a subfolder

## Start

To start n8n in a subfolder simply start docker-compose by executing the following
command in the current folder.

**IMPORTANT:** But before you do that change the default users and passwords in the `.env` file!

```
docker compose up -d
```

To stop it execute:

```
docker compose stop
```

## Upgrade Considerations

### n8n 3.0

`N8N_VERSION` in the [`.env`](.env) file pins the n8n version this example is tested with. The pin moves to n8n 3.x when 3.0 becomes n8n's stable release.

Before you upgrade:

- Read the [n8n 3.0 breaking changes](https://docs.n8n.io/changelog/v30-breaking-changes/).
- Open **Settings > Migration Report** in n8n. It lists what on your instance needs attention.
- Back up `${DATA_FOLDER}/.n8n`. It holds the SQLite database and the encryption key. n8n migrates its database forward when it starts, so the backup is your way back to 2.x.

To stay on n8n 2.x, keep `N8N_VERSION` at your current 2.x version when you take a newer copy of this folder.
