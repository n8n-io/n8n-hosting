# 🧪 n8n hosting lab

**Deploy n8n the way the `n8n-hosting` files deploy it, on your laptop or a cloud, and see if it works.**

Real n8n runs in minikube, Docker, EKS or AKS, from the `n8n-hosting` Helm chart, `kubernetes/` manifests and Compose files. Use any n8n-hosting branch and any n8n image, released or built from a branch.

[Addons](#-addons-and-generic-settings) add what the lab does not know about, such as catching what a deployment reports about itself.

---

## ⚡ 30-second start

```bash
./lab up k8s        # deploy the kubernetes/ manifests with the released n8n
./lab status        # see the pods
```

---

## 🧭 What do you want to do?

| I want to... | Run |
| --- | --- |
| Test the `kubernetes/` manifests | `./lab up k8s` |
| Test a Compose stack | `./lab up compose-with-postgres` |
| Test a Helm chart change | `HOSTING=<n8n-hosting worktree> ./lab up queue` |
| Test an unreleased n8n branch | [Build an image](#-test-an-unreleased-n8n-branch), then `N8N_IMAGE=... ./lab up k8s` |
| Test both at once | `HOSTING=<worktree> N8N_IMAGE=n8n-<name> N8N_TAG=latest ./lab up k8s` |
| Check a deployment works | `./lab check` |
| Test an upgrade | `./lab upgrade queue --from 2.30.0` |
| Test a chart example | `./lab up example-minimal` |
| Run a workflow through a deployment | `./lab check --e2e` |
| Try an n8n setting | `./lab up queue --env N8N_LOG_LEVEL=debug` |
| Remove one deployment | `./lab down k8s` |
| Remove everything | `./lab down` |

---

## 🧩 How it fits together

Two choices, and they do not depend on each other.

```
  WHICH n8n CODE?                 HOW IS IT DEPLOYED?
                                                                          optional
  released image      ──┐         Helm chart                ──┐
        or              ├──►      kubernetes/ manifests     ──┼──►   deployed n8n   ──►   addons
  any n8n branch      ──┘         Docker Compose             ──┘
  (build-image.sh)                (./lab up <target>)
```

---

## ✅ Before you start

- **Node 24 or later**, then `pnpm install` once in this folder.
- `kubectl` and `helm`. Compose targets also need Docker Compose 2.24 or later (`docker compose`, or the standalone `docker-compose`).
- For the local provider: Docker (Colima) and minikube. If `kubectl` is refused: `colima start && minikube start`. minikube needs at least **8 GiB**; `./lab up` checks this and prints the fix.
- For a cloud provider: that provider's CLI. The lab uses it directly and stops with an install hint if it is missing.

---

## ☁️ Providers

By default the lab runs on minikube. Pick another place with `--provider` or `LAB_PROVIDER`:

| Provider | Needs | Notes |
| --- | --- | --- |
| `minikube` (default) | `minikube`, `docker` | Free. Runs every target, including Compose |
| `azure` | `az` | Creates an AKS cluster in its own resource group, 1 x Standard_B2ms (`LAB_AZURE_NODE_SIZE`, `LAB_AZURE_NODES`). Location from `AZURE_LOCATION` or the Azure CLI config. The node costs about $0.08 an hour and the control plane is free. Chart and `k8s` targets only |
| `aws` | `aws`, `eksctl` | Creates an EKS cluster, 1 x t3.large (`LAB_AWS_NODE_TYPE`, `LAB_AWS_NODES`). Region from `AWS_REGION` or the AWS CLI config. Costs about $0.20 an hour. Chart and `k8s` targets only |

```bash
./lab up queue --provider aws        # lists your clusters, or creates one
./lab down --provider aws            # removes the deployments, keeps the cluster
./lab cluster delete lab-<you> --provider aws
```

- A cloud `up` asks before it creates a cluster. Pass `--yes` to skip the question.
- `./lab down` removes deployments only. The cluster stays, and a cloud cluster keeps costing money until you delete it with `./lab cluster delete <name>`.
- On a cloud, `N8N_IMAGE` must point at a registry image. Images built by `build-image.sh` only exist inside minikube.
- A provider only has to hand back a kube context, so adding another cloud means one new entry in `src/providers.ts`.

---

## 🗂️ Clusters

A cluster outlives its deployments, so you can keep one, tear the deployments down, and redo them.

| Command | What it does |
| --- | --- |
| `./lab up` | Lists your clusters and lets you pick one or create a new one. Enter takes the current one |
| `./lab up --cluster <name>` | Uses that cluster, or creates it if it does not exist |
| `./lab clusters` | Lists the clusters for the provider. `*` marks the current one |
| `./lab status` | Shows the current cluster and, for a cloud cluster, how long it has run and what it costs |
| `./lab down` | Removes deployments. The cluster stays |
| `./lab cluster delete <name>` | Destroys a cluster and everything in it. Asks first |

The current cluster is remembered per provider in `.lab-state.json`. Without a terminal, `up` uses the current or only cluster, and asks you to pass `--cluster` when it cannot tell. On AWS the lab lists and deletes only clusters whose name starts with `lab-`.

---

## 🎯 Targets

| Target | What it deploys | Where |
| --- | --- | --- |
| `single` | Helm chart. One pod, SQLite | namespace `lab-single` |
| `queue` | Helm chart. Main, 2 workers, Postgres, Redis | namespace `lab-queue` |
| `webhooks` | `queue` plus 2 webhook processors | namespace `lab-webhooks` |
| `multimain` | `webhooks` plus multi-main. Needs `N8N_LICENSE_KEY` (Enterprise) | namespace `lab-multimain` |
| `k8s` | The `kubernetes/` manifests from n8n-hosting | namespace `lab-k8s` |
| `compose-with-postgres` | `docker-compose/withPostgres` | Docker project `lab-compose-with-postgres` |
| `compose-with-postgres-and-worker` | `docker-compose/withPostgresAndWorker` | Docker project `lab-compose-with-postgres-and-worker` |
| `compose-caddy` | `docker-caddy`, the `n8n` service only | Docker project `lab-compose-caddy` |
| `compose-subfolder-with-ssl` | `docker-compose/subfolderWithSSL`, the `n8n` service only | Docker project `lab-compose-subfolder-with-ssl` |

- `example-<name>` deploys `charts/n8n/examples/<name>.yaml`. See [Chart examples](#-chart-examples).
- `./lab up` with no target runs `single queue webhooks multimain`.
- Pick several: `./lab up k8s queue`.
- Safe to rerun. It updates what exists and keeps encryption keys.

**About `k8s`:** the manifests are applied as shipped, with two changes made in memory (your files stay untouched):

1. The namespace `n8n` becomes `lab-k8s`, so the lab never touches a real install.
2. The Deployment gets the lab settings, and your local image when `N8N_IMAGE` is set.

**About Compose:** the files run as shipped. A generated override in `.compose/` adds the lab settings and the local image, and frees the host port so stacks run side by side. The Caddy and subfolder targets start only `n8n`, never the proxy. They get a data folder under `.compose/data/<target>`, which `down` removes, and the Caddy volumes become project-scoped so they never touch real ones.

---

## 🩺 Check a deployment

`./lab check` smoke-tests every deployed target. Pass names to check only some: `./lab check queue k8s`.

| Check | Passes when |
| --- | --- |
| Pods ready | Every deployment is Available (cluster targets) |
| Health | `/healthz` answers 200 |
| Readiness | `/healthz/readiness` answers 200, so n8n reached its database |
| Editor loads | `/` answers 200 with the n8n page |
| Webhook route answers | `/webhook/...` answers 404 from n8n, on a webhook processor when there is one |

Each check retries for about 20 seconds, so it is safe to run right after `up`. It exits 1 when anything fails. The subfolder stack serves under a path prefix, so only its health checks run.

`./lab check --e2e` also runs a workflow: it creates an owner (`lab-e2e@example.com`) and a webhook workflow, calls the webhook (through a webhook processor when there is one), checks the answer and removes the workflow. In queue mode this proves a worker ran the job. It needs a recent n8n.

---

## ⬆️ Test an upgrade

Most real installs break when they upgrade. This tests that:

```bash
./lab upgrade queue --from 2.30.0
```

It runs the steps below and fails at the first one that breaks:

1. Installs the target at `--from` and checks the running version.
2. Runs `check`.
3. Saves a marker workflow.
4. Upgrades to `--to`. Without `--to`, it uses the version the files ship with.
5. Checks the new version, runs `check` again, and confirms the marker workflow is still there.

The target must not exist yet, so the test starts from a clean install. Run `./lab down <target>` afterwards. It works for chart, `k8s` and Compose targets.

---

## 📚 Chart examples

Every file in `charts/n8n/examples/` is a target named `example-<file>`. The lab applies the example as shipped, then lays `values/common.yaml` over it. That points the database and Redis at the lab's own, shrinks pods, turns autoscalers off, and creates every secret the example names with random values.

| Example | Result |
| --- | --- |
| `minimal`, `minimal-with-docker`, `standalone`, `https-ingress`, `mcp-server`, `task-runners` | ✅ Deploy and pass `check` |
| `keda-autoscaling` | ❌ Needs KEDA installed. The lab stops with the install command |
| `node-placement` | ❌ Needs nodes labelled `pool=n8n-frontend` and `pool=n8n-workers`. One minikube node cannot be both |
| `multi-main-queue`, `production-s3` | Need an Enterprise key. Not tested yet |

A target with a missing prerequisite fails in seconds, before it creates anything, and says how to fix it. The other targets still deploy.

---

## 🌿 Test an unreleased n8n branch

Use this when the n8n code you want to test is not released yet.

**1. Build the packages the branch touched**, in your n8n worktree:

```bash
pnpm --filter <package> build
```

**2. Build a lab image.** Pick any name:

```bash
./build-image.sh ~/git/n8n-wt-my-branch my-branch
```

This copies the branch's compiled files over the `nightly` image and loads the result into minikube as `n8n-my-branch:latest`. It takes seconds.

**3. Deploy with it:**

```bash
N8N_IMAGE=n8n-my-branch N8N_TAG=latest ./lab up k8s
```

**Limits.** The branch must sit reasonably close to `nightly`. It can only touch packages `build-image.sh` knows about. For an unknown package the script stops and names the one to add.

---

## 🌱 Test a branch of n8n-hosting

Point `HOSTING` at the checkout or worktree that holds your change:

```bash
HOSTING=~/git/n8n-hosting-wt-some-branch ./lab up k8s queue
```

It covers the chart (`charts/n8n`), the manifests (`kubernetes/`) and the Compose files (`docker-compose/`). The default is the repository the lab sits in (`tools/lab` inside `n8n-hosting`), else `~/git/n8n-hosting`.

---

## 🔌 Addons and generic settings

Three options work on any target, so nothing special is needed to try a setting:

```bash
./lab up queue --env N8N_LOG_LEVEL=debug          # an extra n8n setting on every pod. Repeat it
./lab up queue --values my-values.yaml            # a Helm values file laid over the lab's own. Repeat it
./lab up queue --addon ~/git/my-addon             # load an addon from a folder or file. Repeat it
```

n8n's own diagnostics are **off** unless you turn them on with `--env` or an addon, so a lab deployment never reports to n8n's servers.

An **addon** adds something the lab does not know about: extra n8n settings, things to deploy, new commands. It is one file that exports `(lab) => ({ name, env?, beforeUp?, afterUp?, afterDown?, commands? })`. See `src/addons.ts` for the hooks and what `lab` gives it. A bare name such as `--addon foo` loads `addons/foo/index.ts` in this folder; a path loads a folder or file anywhere. `LAB_ADDONS=a:b` loads them every time.

---

## ⚙️ Settings

All optional. Set them in front of the command.

| Variable | What it does | Default |
| --- | --- | --- |
| `HOSTING` | n8n-hosting checkout to deploy from | the repo the lab sits in, else `~/git/n8n-hosting` |
| `N8N_IMAGE` | Local image already in minikube, such as `n8n-my-branch` | the image the files ship with |
| `N8N_TAG` | Image tag, such as `latest` or `nightly` | the tag the files ship with |
| `N8N_LICENSE_KEY` | Enterprise key for `multimain` | asked for, Enter skips it |
| `CHART` | Path to the chart, if it is not under `HOSTING` | `$HOSTING/charts/n8n` |
| `LAB_ADDONS` | Addons to load, separated by colons | none |

---

## 🪤 Things that trip people up

- **`up` hangs on a licence question.** Run it with `</dev/null`, or set `N8N_LICENSE_KEY`.
- **`kubectl` is refused.** `colima start && minikube start`.

---

## 🧹 Start over

```bash
./lab down k8s      # remove one target
./lab down          # remove everything, addon data included
```

---

## 📁 What is in this folder

| Path | Job |
| --- | --- |
| `lab` | The CLI. Runs `src/cli.ts` |
| `src/` | The CLI: `cli.ts` commands, `providers.ts` places to run, `targets.ts` what to deploy, `addons.ts` the addon hooks |
| `build-image.sh` | Builds a lab image from any n8n branch |
| `manifests/` | Postgres and Redis for the chart targets |
| `values/common.yaml` | Helm values shared by every chart target |
| `addons/` | Optional addons, none shipped. See [Addons](#-addons-and-generic-settings) |
