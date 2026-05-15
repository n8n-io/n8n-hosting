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
