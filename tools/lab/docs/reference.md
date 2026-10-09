# Reference

Every target, command, setting and rule. For a first run, start with the [README](../README.md).

**Contents:** [Targets](#targets) · [Clusters](#clusters) · [Checks](#checks) · [Upgrade test](#upgrade-test) · [Unreleased n8n branch](#test-an-unreleased-n8n-branch) · [Generic settings](#generic-settings-and-addons) · [Safety rules](#safety-rules) · [Settings and troubleshooting](#settings-and-troubleshooting)

---

## Targets

| Target | What it deploys | Runs on |
| --- | --- | --- |
| `single` | Helm chart, one pod, SQLite | any provider |
| `queue` | Helm chart, main, 2 workers, Postgres, Redis | any provider |
| `webhooks` | `queue` plus 2 webhook processors | any provider |
| `multimain` | `webhooks` plus multi-main. Needs `N8N_LICENSE_KEY` (Enterprise) | any provider |
| `k8s` | the `kubernetes/` manifests | any provider |
| `compose-with-postgres` | `docker-compose/withPostgres` | local Docker (minikube provider) |
| `compose-with-postgres-and-worker` | `docker-compose/withPostgresAndWorker` | local Docker (minikube provider) |
| `compose-caddy` | `docker-caddy`, the `n8n` service only | local Docker (minikube provider) |
| `compose-subfolder-with-ssl` | `docker-compose/subfolderWithSSL`, the `n8n` service only | local Docker (minikube provider) |
| `example-<name>` | `charts/n8n/examples/<name>.yaml` | any provider |

- `./lab up` with no target runs `single queue webhooks multimain`. Name several to run them side by side: `./lab up k8s queue`.
- **Chart targets** install the chart with the topology set by `--set` flags, then lay `values/common.yaml` over it (small requests so four installs fit on one node, and the lab's own Postgres and Redis).
- **`k8s`** applies the manifests with two in-memory changes: the namespace becomes `lab-k8s` so a real install is never touched, and the Deployment gets the lab settings.
- **Compose** runs the files as shipped. A generated override in `.compose/` adds the lab settings and frees the host port so stacks run side by side. The proxy in the Caddy and subfolder stacks is not started.
- **`example-<name>`** deploys a chart example as shipped, creates every secret it names with random values, and turns autoscalers off. If an example needs something the cluster lacks (KEDA, labelled nodes, a licence key), the lab stops in seconds and says how to fix it.

---

## Clusters

A cluster outlives its deployments, so you can tear deployments down and redo them on the same cluster.

| Command | What it does |
| --- | --- |
| `./lab up` | lists your clusters, lets you pick one or create one |
| `./lab up --cluster <name>` | uses that cluster, or creates it |
| `./lab clusters` | lists the clusters for the provider |
| `./lab status` | the current cluster, its pods, and what it costs |
| `./lab down` | removes deployments, keeps the cluster |
| `./lab cluster delete <name>` | destroys a cluster and everything in it. Asks first |

---

## Checks

```bash
./lab check            # every deployed target
./lab check queue k8s  # only these
./lab check --e2e      # also run a workflow
```

| Check | Passes when |
| --- | --- |
| Pods ready | every deployment is Available (cluster targets) |
| Health | `/healthz` answers 200 |
| Readiness | `/healthz/readiness` answers 200, so n8n reached its database |
| Editor loads | `/` answers 200 with the n8n page |
| Webhook route answers | `/webhook/...` answers 404 from n8n (from a webhook processor when there is one) |
| **`--e2e`**: workflow runs | a workflow is created, its webhook is called, and the result it computed comes back |

Each check retries for about 20 seconds, so it is safe to run right after `up`. The command exits 1 when anything fails.

**What `--e2e` does.** Inside the pod it creates an owner (`lab-e2e@example.com`, with a password derived from the install's own encryption key, so nothing is passed on a command line), creates a webhook workflow, calls the webhook, checks the answer contains a random value it sent, and deletes the workflow. In queue mode that proves a worker really ran the job. It needs a recent n8n.

---

## Upgrade test

Most real installs break when they upgrade, on a database migration. This tests it:

```bash
./lab upgrade queue --from 2.30.0                  # up to the version the files ship with
./lab upgrade queue --from 2.30.0 --to 2.40.0
```

It installs `--from`, checks it, saves a marker workflow, upgrades, checks again, and confirms the marker survived. The target must not exist yet, so it always starts from a clean install.

---

## Test an unreleased n8n branch

```bash
pnpm --filter <package> build                      # in your n8n worktree
./build-image.sh ~/git/n8n-wt-my-branch my-branch
N8N_IMAGE=n8n-my-branch N8N_TAG=latest ./lab up k8s
```

`build-image.sh` copies the branch's compiled files over a `nightly` image, so it takes seconds, not a full image build. The branch must sit reasonably close to `nightly`. On a cloud, push to a registry the cluster can pull from: `./lab registry`.

---

## Generic settings and addons

```bash
./lab up queue --env N8N_LOG_LEVEL=debug           # an extra n8n setting on every pod. Repeat it
./lab up queue --values my-values.yaml             # a Helm values file laid over the lab's own
```

n8n's own diagnostics are **off** in every lab deployment unless you turn them on with `--env`, so a lab never reports to n8n's servers.

An **addon** adds what the lab does not know about. See [Extending](extending.md#write-an-addon).

---

## Safety rules

The lab is meant to be pointed at accounts and machines with real things in them, so it is careful.

| Rule | How |
| --- | --- |
| **Never touches a cluster it was not told to** | `kubectl` and `helm` refuse to run without an explicit context |
| **Only removes what it created** | every namespace carries `app.kubernetes.io/managed-by=n8n-hosting-lab`, and `down` only deletes labelled ones, whatever their name |
| **Never deletes a cluster that is not its own** | AWS and Azure clusters must carry the `lab=n8n-hosting-lab` tag to be listed or deleted. minikube lists every profile, so deleting one needs its name typed |
| **Cloud means cost, so it asks** | creating a cluster shows the plan and asks. `down` never deletes a cluster. `status` shows what a running one costs |
| **Secrets stay off command lines** | they travel on stdin or from the environment, and are never printed. Keys are random and created once |
| **Never writes to the files it deploys** | the chart, manifests and Compose files are applied as shipped. Changes happen in memory or in a generated override |
| **Nothing phones home** | n8n diagnostics are off in every lab deployment |
| **A missing tool is an error** | with an install hint, before anything is created. It never silently falls back |

---

## Settings and troubleshooting

| Variable | What it does | Default |
| --- | --- | --- |
| `HOSTING` | the checkout to deploy from | the repo the lab sits in, else `~/git/n8n-hosting` |
| `CHART` | path to the chart | `$HOSTING/charts/n8n` |
| `N8N_IMAGE`, `N8N_TAG` | the image to deploy. On a cloud it must be in a registry | what the files ship with |
| `N8N_LICENSE_KEY` | Enterprise key for `multimain` and licensed examples | asked for, Enter skips it |
| `LAB_PROVIDER` | default provider | `minikube` |
| `LAB_ADDONS` | addons to load, separated by colons | none |
| `AWS_REGION` | AWS region | the AWS CLI config |
| `AZURE_LOCATION` | Azure region | the Azure CLI config |
| `LAB_AWS_NODE_TYPE`, `LAB_AWS_NODES` | EKS node type and count | `t3.large`, 1 |
| `LAB_AZURE_NODE_SIZE`, `LAB_AZURE_NODES` | AKS node size and count | `Standard_B2ms`, 1 |

**Common snags**

- **`up` waits on a licence question.** Set `N8N_LICENSE_KEY`, or run with `</dev/null` to skip licensed targets.
- **`kubectl` is refused (local).** Start your Docker runtime and minikube, for example `colima start && minikube start`.
- **minikube has too little memory.** The lab needs about 6 GiB, and `up` wants 8 or more. It prints the `docker update` command that fixes it.
- **A Compose target fails on `!override`.** The generated override needs Docker Compose 2.24 or later.
- **An example needs KEDA or labelled nodes.** The lab stops early and prints the command to install or label.
- **A cloud cluster is still running.** `./lab status --provider aws`, then `./lab cluster delete <name> --provider aws`.

## Development

```bash
pnpm install
pnpm typecheck       # types, for src, test and addons
pnpm test            # unit tests and the layering test. They need no cluster
```

Working on the lab with an AI agent: see [AGENTS.md](../AGENTS.md).
