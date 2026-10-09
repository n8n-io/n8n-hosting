import type { ListrTask } from 'listr2';
import { ensureDefaultStorageClass, type Env } from '../../cluster/kube.ts';
import { pick, remember, selectCluster } from '../../cluster/selection.ts';
import { describeFailure, failedScopes, failures } from '../../support/failures.ts';
import type { Provider } from '../../providers/index.ts';
import { runTasks } from '../../support/tasks.ts';
import { DEFAULT_TARGETS, checkTargets, hasLicenseSecret, isCompose, licensed, mainDeployment, namespaceOf, targetTask } from '../../targets/index.ts';
import { UserError, askHidden, c, confirm } from '../../support/ui.ts';
import type { Command } from './types.ts';

/** A cluster takes minutes to create, so show how long it has been and what it is doing. */
async function createWithTimer(provider: Provider, name: string, task: { title: string; output: string }): Promise<void> {
  const started = Date.now();
  const tick = setInterval(() => {
    const s = Math.floor((Date.now() - started) / 1000);
    task.title = `${provider.name} cluster ${name} ${c.dim(`${Math.floor(s / 60)}m ${String(s % 60).padStart(2, '0')}s`)}`;
  }, 1000);
  try {
    await provider.create(name, (line) => (task.output = line));
  } finally {
    clearInterval(tick);
  }
}

/** A cloud cluster costs money, so say what it will cost and ask first. */
async function confirmCost(provider: Provider, name: string, yes: boolean): Promise<void> {
  console.log(`${c.yellow('This creates a cloud cluster that costs money.')}\n${c.dim((await provider.plan?.(name)) ?? '')}\n`);
  if (!yes && !(await confirm('Create it?'))) throw new UserError('Cancelled. Pass --yes to skip this question.');
}

/** Picks a cluster (or creates one), connects to it, and makes it the env's cluster. */
async function ensureCluster(env: Env, requested: string | undefined, yes: boolean): Promise<void> {
  const { provider } = env;
  const choice = await pick(provider, requested);
  const found = (await provider.list()).find((e) => e.name === choice.name);
  const needsCreate = choice.isNew || !found?.running;
  if (needsCreate && !provider.local) await confirmCost(provider, choice.name, yes);
  await runTasks([
    {
      title: `${provider.name} cluster ${choice.name}`,
      task: async (_, task) => {
        if (needsCreate) await createWithTimer(provider, choice.name, task);
        await selectCluster(env, choice.name);
        if (!provider.local) await ensureDefaultStorageClass(env, (line) => (task.output = line));
        remember(provider, choice.name);
      },
    },
  ]);
}

/** Licensed targets need an Enterprise key, unless their namespace already holds one. Returns the targets that can run. */
async function withLicenceKeys(env: Env, targets: string[]): Promise<string[]> {
  const missing: string[] = [];
  for (const t of targets.filter((t) => licensed(env, t))) if (!(await hasLicenseSecret(env, t))) missing.push(t);
  if (missing.length && !env.licenseKey && process.stdin.isTTY) {
    env.licenseKey = (await askHidden(`Enterprise licence key for ${missing.join(', ')} ${c.dim('(Enter to skip)')}: `)) || undefined;
  }
  if (!missing.length || env.licenseKey) return targets;
  console.log(c.yellow(`Skipping ${missing.join(', ')}: no licence key.\n`));
  return targets.filter((t) => !missing.includes(t));
}

/** Addons first, then every target at once, then addons again. */
function deployTasks(env: Env, targets: string[]): ListrTask[] {
  return [
    ...env.addons.filter((a) => a.beforeUp).map((a): ListrTask => ({ title: `${a.name} (addon)`, task: (_, task) => a.beforeUp!(env, (l) => (task.output = l)) })),
    { title: 'Targets', task: (_, task) => task.newListr(targets.map((t) => targetTask(env, t)), { concurrent: true, exitOnError: false }) },
    ...env.addons.filter((a) => a.afterUp).map((a): ListrTask => ({ title: `${a.name} (addon, after)`, task: (_, task) => a.afterUp!(env, targets, (l) => (task.output = l)) })),
  ];
}

/** What worked, what did not, and how to open an editor. Throws when nothing was deployed. */
function report(env: Env, targets: string[]): void {
  const broken = failedScopes();
  const deployed = targets.filter((t) => !broken.has(t));
  if (broken.size) console.log(`\n${c.red(`${broken.size} of ${targets.length} targets failed:`)}\n${failures().map((f) => `  ${describeFailure(f)}`).join('\n')}`);
  if (!deployed.length) throw new UserError('Nothing was deployed.');
  console.log(`\n${c.green(broken.size ? 'The rest deployed.' : 'Done.')}`);

  const inCluster = deployed.filter((t) => !isCompose(t));
  if (inCluster.length) console.log(c.dim('Open an editor with:'));
  for (const t of inCluster) console.log(`  kubectl --context ${env.ctx} -n ${namespaceOf(t)} port-forward svc/${mainDeployment(t)} 5678`);

  // Compose targets publish no host port, so stacks can run side by side.
  const compose = deployed.filter(isCompose);
  if (compose.length) console.log(c.dim('Compose targets publish no port. Check one is healthy with:'));
  for (const t of compose) console.log(`  docker exec lab-${t}-n8n-1 wget -qO- http://localhost:5678/healthz`);
  console.log();
}

export const up: Command = async (env, args, opts) => {
  const requested = checkTargets(env, args.length ? args : DEFAULT_TARGETS);
  await ensureCluster(env, opts.cluster, opts.yes);
  const targets = await withLicenceKeys(env, requested);
  await runTasks(deployTasks(env, targets));
  report(env, targets);
};
