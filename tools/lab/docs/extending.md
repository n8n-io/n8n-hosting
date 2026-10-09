# Extending the lab

How to add a target, a provider, a check, a command or an addon. Read [Architecture](architecture.md) first: the lab is built in layers, and each of these goes in one place.

| I want to add | It goes in | Size |
| --- | --- | --- |
| a Helm topology | `src/targets/chart.ts` | one line |
| another kind of target | `src/targets/<name>.ts` | one file |
| a cloud | `src/providers/<name>.ts` | one file |
| a check | `src/testing/check.ts` | one line |
| a command | `src/cli/commands/<name>.ts` | one file |
| something private or optional | an addon, outside the lab | one file |

After any change: `pnpm typecheck` and `pnpm test`.

---

## Add a target

A target is a name plus a list of steps. They live in `src/targets/`.

1. **A new Helm topology** is one line: add its `--set` values to `TOPOLOGY` in `chart.ts`, and its name to `CHART_TARGETS` in `names.ts`.
2. **Something else** gets its own file with a function that returns steps, like `k8s.ts`. Wire it into `stepsFor` in `targets/index.ts`.
3. Add a one-line description to `DESCRIPTION` in `names.ts`, so it shows in `--help`.
4. Make sure `testing/exec.ts` can reach it (`execFor`).

Build steps with the helpers in `steps.ts` (`step`, `ensureChartSecrets`, `helmInstall`, `waitForRollouts`). They create secrets once, set Helm values in the right order and record failures for you.

## Add a provider

A provider lists, creates, connects to and destroys named clusters. It only has to give back a kube context. Add `src/providers/<name>.ts` and register it in `src/providers/index.ts`:

```ts
interface Provider {
  name: string;
  local: boolean;                  // local providers can use loaded images and run Compose
  shared?: boolean;                // the cluster list may hold clusters that are not the lab's
  clis: string[];                  // checked before anything is created, with an install hint
  defaultName(): string;
  list(): Promise<Cluster[]>;      // only the lab's own clusters (check the lab tag)
  create(name, log): Promise<void>;
  connect(name): Promise<string>;  // returns the kube context
  destroy(name, log): Promise<void>;
  plan?(name): Promise<string>;    // shown before a cloud cluster is created: cost and time
  info?(name): Promise<string>;    // shown by `status`: how long it has run, what it costs
  registry?: { ensure; remove };   // a registry the cluster can pull from
}
```

Rules a cloud provider follows: tag everything with the lab tag (`providers/lab.ts`), list and delete only clusters that carry it, put the provider name in the kube context (`aws-<name>`), and never delete anything in `down`. Add an install hint for its CLI in `providers/index.ts`.

## Add a check

Use the `checker` helper in `src/testing/check.ts`. It retries, and it records a failure so the exit code is right:

```ts
const check = checker(target);
check('Metrics endpoint answers', () => expectStatus(main, '/metrics', 200))
```

## Add a command

Write `src/cli/commands/<name>.ts` exporting a `Command` (`(env, args, opts) => Promise<void>`), add it to `STANDALONE` or `ON_CLUSTER` in `src/cli/index.ts`, and a line to `src/cli/help.ts`. Keep a command short: it parses nothing and decides little. It calls into the layers below.

## Write an addon

An addon adds something the lab does not know about: extra n8n settings, extra things to deploy, extra commands. It is one file:

```ts
// my-addon/index.ts
import type { Addon, LabApi } from '<path to the lab>/src/addons.ts';

export default function (lab: LabApi): Addon {
  return {
    name: 'my-addon',
    // extra n8n settings for each target. `source` is the target, `compose` says it runs in Docker
    env: ({ source }) => ({ N8N_LOG_LEVEL: 'debug' }),
    // deploy something before the targets run
    beforeUp: async (env, log) => { await lab.ensureNs(env, 'lab-my-addon', 'my-addon'); },
    // clean up when `./lab down` runs with no target
    afterDown: async (env, all, log) => { if (all) await lab.removeNamespaces(env, ['lab-my-addon'], log); },
    // new commands: ./lab hello
    commands: { hello: { help: 'say hello', run: async () => console.log('hello') } },
  };
}
```

```bash
./lab up queue --addon ./my-addon        # a folder or a file anywhere
LAB_ADDONS=./my-addon ./lab up queue     # or every time
./lab --addon ./my-addon --help          # its commands show up in the help
```

Every hook is optional (`env`, `beforeUp`, `afterUp`, `afterDown`, `commands`). `lab` hands an addon `kubectl`, `apply`, `ensureNs`, `exists`, `removeNamespaces`, `run`, the terminal helpers and `ROOT`; see `src/addons.ts`. Pass the addon's name to `ensureNs` so its namespace is not mistaken for a target.
