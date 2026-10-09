# n8n hosting lab

A CLI that deploys n8n the way the `n8n-hosting` files deploy it, on local minikube or a cloud, so every deployment type can be tested. This file is for AI agents; humans start with [README.md](README.md).

## Run it

```bash
pnpm install          # once
./lab --help          # every command, target and setting
```

Node 24 or later runs the TypeScript directly. There is no build step. Check types with `pnpm typecheck`.

## Which command for which goal

| Goal | Command |
| --- | --- |
| Deploy one topology | `./lab up queue` |
| Deploy with an unreleased n8n branch | `./build-image.sh <worktree> <name>`, then `N8N_IMAGE=n8n-<name> N8N_TAG=latest ./lab up <target>` |
| Deploy an n8n-hosting branch | `HOSTING=<worktree> ./lab up <target>` |
| See what is running | `./lab status` |
| Check a deployment works | `./lab check [target]` |
| Also run a workflow through a webhook | `./lab check [target] --e2e` |
| Test an upgrade | `./lab upgrade <target> --from <version> [--to <version>]` |
| Test a chart example | `./lab up example-<name>`. Names come from `charts/n8n/examples/` |
| Try an n8n setting or Helm values | `./lab up <target> --env KEY=VAL`, `--values file.yaml` |
| Run on AWS | `./lab up <target> --provider aws` (region from `AWS_REGION` or the AWS CLI config) |
| Run on Azure | `AZURE_LOCATION=<location> ./lab up <target> --provider azure` |
| Clean up deployments | `./lab down [target]`. No target removes every deployment. The cluster stays |
| See or choose a cluster | `./lab clusters`, `./lab up --cluster <name>` |
| Destroy a cluster | `./lab cluster delete <name>` |

## Layout

- `src/cli.ts`: commands, arguments, progress output.
- `src/providers.ts`: where the lab runs. A provider lists, creates, connects to and destroys named clusters. Add a cloud here.
- `src/clusters.ts`: choosing the cluster to use, and remembering it in `.lab-state.json`.
- `src/targets.ts`: what each target deploys.
- `src/check.ts`: the smoke tests behind `./lab check`.
- `src/e2e.ts`: the `--e2e` check: creates an owner and a webhook workflow, calls it, removes it.
- `src/upgrade.ts`: the upgrade test. It reuses the target and check tasks.
- `src/examples.ts`: reads the chart examples and finds the secrets and licence needs in them.
- `src/kube.ts`, `src/sh.ts`, `src/ui.ts`: kubectl and helm wrappers, process runner, terminal styling.
- `src/addons.ts`: the addon hooks. `addons/<name>/index.ts` is one addon.

## Rules

- **Never write to the files it deploys.** Treat `HOSTING` (by default this repository) as read-only: the lab applies its files as shipped and changes them only in memory or in a generated override.
- **Addons stay optional.** Nothing outside `addons/<name>/` may need an addon. n8n diagnostics are off unless an addon or `--env` turns them on.
- **A missing provider CLI is an error with an install hint**, never a silent fallback. Check CLIs in `requireClis` before anything is created.
- **Cloud means cost.** Creating a cluster asks first. `down` never deletes a cluster; only `cluster delete` does, and it asks. Tag everything the lab creates, and only list or delete clusters that carry the lab tag. Namespaces carry `app.kubernetes.io/managed-by=n8n-hosting-lab`, and `down` only removes those.
- **Never run `./lab down` or `cluster delete` to "test" something.** They remove real deployments. Use a read-only command, or a dry target name.
- **Credentials stay out of arguments and files.** Secrets travel on stdin or from the environment. Never print them.
- **Failures must reach the exit code.** listr2 subtask failures do not fail the top-level run, so steps and checks record them (`failures` in `targets.ts`, `failed` in `check.ts`). Keep doing that for new steps.
- **`up` is safe to rerun.** Secrets are created once so an encryption key never changes under a running install.
- **Keep it generic.** No customer names, internal ticket ids or personal names in code, docs or examples.
