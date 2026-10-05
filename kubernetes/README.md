# n8n-kubernetes-hosting

> **For production Kubernetes deployments, use the official [n8n Helm chart](../charts/n8n/).** The raw manifests below are intended for tutorial-based deployments and simple setups.

Get up and running with n8n on the following platforms:

* [AWS](https://docs.n8n.io/hosting/server-setups/aws/)
* [Azure](https://docs.n8n.io/hosting/server-setups/azure/)
* [Google Cloud Platform](https://docs.n8n.io/hosting/server-setups/google-cloud/)

If you have questions after trying the tutorials, check out the [forums](https://community.n8n.io/).

## Prerequisites

Self-hosting n8n requires technical knowledge, including:

* Setting up and configuring servers and containers
* Managing application resources and scaling
* Securing servers and applications
* Configuring n8n

n8n recommends self-hosting for expert users. Mistakes can lead to data loss, security issues, and downtime. If you aren't experienced at managing servers, n8n recommends [n8n Cloud](https://n8n.io/cloud/).

## Upgrade Considerations

### PostgreSQL 18

`postgres-deployment.yaml` runs `postgres:18`.

**Installing fresh:** nothing to do. Apply the manifests as usual.

**Upgrading an existing cluster:** this is a major version upgrade and it is breaking. Postgres 18
cannot open a data directory written by 16, and moving the folder does not help, because the check
is on the format and not the path. The pod stays in `CrashLoopBackOff` with
`FATAL: database files are incompatible with server`. Nothing is deleted, and you can pin the image
back to `postgres:16` at any point.

Follow the official guide,
[Upgrading a PostgreSQL Cluster](https://www.postgresql.org/docs/18/upgrading.html). It covers the
three supported methods and which to pick.

For a small cluster, dump and restore is usually simplest. n8n is offline while you do it:

```bash
# 0. The Postgres superuser name, as set in postgres-secret.yaml
POSTGRES_USER=changeUser

# 1. Export, with the old image still running
kubectl exec -n n8n deploy/postgres -- pg_dumpall -U "$POSTGRES_USER" > n8n-backup.sql

# 2. Check the export worked. This must print 1
grep -c "PostgreSQL database cluster dump complete" n8n-backup.sql

# 3. Stop n8n, so it cannot rebuild its schema against the empty database and
#    collide with the import
kubectl scale deploy/n8n --replicas=0 -n n8n

# 4. Delete Postgres and ONLY its claim, then recreate just Postgres. The guard
#    repeats the check, so a failed export stops here instead of deleting
grep -q "PostgreSQL database cluster dump complete" n8n-backup.sql \
  && kubectl delete deploy/postgres pvc/postgresql-pv -n n8n \
  && kubectl apply -f postgres-claim0-persistentvolumeclaim.yaml -f postgres-deployment.yaml

# 5. Import
kubectl exec -i -n n8n deploy/postgres -- psql -U "$POSTGRES_USER" -d n8n < n8n-backup.sql

# 6. Import done, start n8n again
kubectl scale deploy/n8n --replicas=1 -n n8n
```

One thing specific to this setup, which that guide cannot tell you: **only `postgresql-pv` should
be deleted.** Keep the `n8n-claim0` claim, it holds n8n's encryption key. Without it you would
restore the database fine and every saved credential would stay unreadable.

## Contributions

Please open PRs to the `main` branch.
