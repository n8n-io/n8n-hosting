# n8n hosting lab

A CLI that deploys n8n the way the `n8n-hosting` files deploy it, on local minikube or a cloud, so every deployment type can be tested. This file is for AI agents; humans start with [README.md](README.md).

## Run it

```bash
pnpm install          # once
./lab --help          # every command, target and setting
```

Node 24 or later runs the TypeScript directly. There is no build step. Check types with `pnpm typecheck`, run the unit tests with `pnpm test`.

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

The full picture, with diagrams, is in [docs/architecture.md](docs/architecture.md). Adding something: [docs/extending.md](docs/extending.md).

`src/` is layers. A layer only imports from the layers below it, and `test/architecture.test.ts` enforces that.

| Layer | What is in it |
| --- | --- |
| `src/cli/` | `index.ts` picks the provider and cluster and runs one command. `options.ts` flags, `help.ts` help text, `commands/` one small file per command (`up`, `down`, `status`, `check`, `upgrade`, `clusters`, `registry`). |
| `src/testing/` | `check.ts` smoke tests, `e2e.ts` and `e2e-client.js` the workflow test (the client runs inside the pod), `upgrade.ts` the upgrade test. |
| `src/targets/` | What each target deploys. `chart.ts`, `example.ts`, `k8s.ts`, `compose.ts` are the steps for each kind, `steps.ts` the helpers they share, `names.ts` the names, `chart-examples.ts` reads `charts/n8n/examples`. |
| `src/providers/` | Where the lab runs. One file per provider (`minikube`, `eks`, `aks`), the interface in `types.ts`, the lab tag and name rules in `lab.ts`. Add a cloud here. |
| `src/cluster/` | `kube.ts` the `Env` and the kubectl and helm wrappers, `namespaces.ts` the lab's label and namespace cleanup, `settings.ts` the n8n settings every deployment gets, `selection.ts` choosing and remembering a cluster. |
| `src/support/` | `sh.ts` process runner, `ui.ts` prompts and colours, `tasks.ts` progress, `failures.ts` the failure list. Knows nothing about the lab. |
| `src/addons.ts` | The addon hooks. `addons/<name>/index.ts` is one addon. |
| `test/` | Unit tests for the pure functions, and the layering test. `pnpm test`. |


## Rules

- **Never write to n8n-hosting.** Treat `HOSTING` as read-only: the lab applies its files as shipped and changes them only in memory or in a generated override.
- **Addons stay optional.** Nothing outside `addons/<name>/` may need an addon. n8n diagnostics are off unless an addon or `--env` turns them on.
- **A missing provider CLI is an error with an install hint**, never a silent fallback. Check CLIs in `requireClis` before anything is created.
- **Cloud means cost.** Creating a cluster asks first. `down` never deletes a cluster; only `cluster delete` does, and it asks. Tag everything the lab creates, and only list or delete clusters that carry the lab tag. Namespaces carry `app.kubernetes.io/managed-by=n8n-hosting-lab`, and `down` only removes those.
- **Never run `./lab down` or `cluster delete` to "test" something.** They remove real deployments. Use a read-only command, or a dry target name.
- **Credentials stay out of arguments and files.** Secrets travel on stdin or from the environment. Never print them.
- **Failures must reach the exit code.** listr2 subtask failures do not fail the top-level run, so steps and checks record them with `recordFailure` (`failures.ts`). The helpers in `targets/steps.ts` and `testing/check.ts` do it for you. Keep using them for new steps.
- **Logic that decides goes in a pure function and gets a test.** Keep the functions that talk to a cluster thin.
- **`up` is safe to rerun.** Secrets are created once so an encryption key never changes under a running install.
- **Keep it generic.** No customer names, internal ticket ids or personal names in code, docs or examples.
