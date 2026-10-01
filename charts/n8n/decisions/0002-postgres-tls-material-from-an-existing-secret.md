# 0002. Postgres TLS material comes from an existing Secret

Date: 2026-10-01
PR: https://github.com/n8n-io/n8n-hosting/pull/222

## Context

n8n reads the Postgres CA, client certificate and client key from `DB_POSTGRESDB_SSL_CA`, `_CERT` and `_KEY`, as PEM contents. The chart took the CA and certificate inline and wrote them to its ConfigMap. It also had a `database.ssl.key` value, but never read it, because a private key does not belong in a ConfigMap. Users who needed mutual TLS had to add the key themselves through `config.extraEnv`, and a key set in `database.ssl.key` was silently ignored.

## Decision

TLS material can come from a Secret the user manages, through `database.ssl.existingSecret`: the Secret's `name`, plus the key inside it for each of `caKey`, `certKey` and `keyKey`. Each key that is set renders one `secretKeyRef` on every n8n component. No key has a default, so the chart only references keys the user named, and a missing key stops the pod at start. This follows "State is external and reached through a contract", and the shape matches how cert-manager and other operators store certificates.

The client key is not accepted inline. Every other datastore credential in this chart, such as the Postgres and Redis passwords and the S3 secret key, is a Secret reference only, and an inline key would sit in the values file and in Helm's release history.

The inline `ca` and `cert` values stay, because they hold public material. Setting the same item both inline and from the Secret fails the render ("One place to set anything, and a defined winner").

## Consequences

`database.ssl.key` still renders in 1.x, but `NOTES.txt` warns that it is not read and names `database.ssl.existingSecret`. Failing the render would break installs that set it, even though it never did anything, so the warning keeps 1.x upgrades in place. In 2.0, `database.ssl.key` fails the render with the replacement named, as retired keys do.

Server verification alone needs no Secret: `database.ssl.enabled: true`, and the CA inline or from the Secret when the server's CA is not publicly trusted.
