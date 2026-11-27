#!/usr/bin/env node
import { type Addon, loadAddons } from '../addons.ts';
import { selectCluster, use } from '../cluster/selection.ts';
import { check } from './commands/check.ts';
import { cluster, clusters } from './commands/clusters.ts';
import { down } from './commands/down.ts';
import { registry } from './commands/registry.ts';
import { status } from './commands/status.ts';
import type { Command } from './commands/types.ts';
import { up } from './commands/up.ts';
import { upgrade } from './commands/upgrade.ts';
import { helpText } from './help.ts';
import { envFromProcess, type Env } from '../cluster/kube.ts';
import { type Options, parseOptions } from './options.ts';
import { getProvider, requireClis } from '../providers/index.ts';
import { UserError, c } from '../support/ui.ts';

/** Commands that choose or create the cluster themselves. */
const STANDALONE: Record<string, Command> = { clusters, cluster, up };

/** Commands that work on a cluster that already exists. */
const ON_CLUSTER: Record<string, Command> = { down, registry, status, check, upgrade };

const addonCommands = (addons: Addon[]): Record<string, Command> =>
  Object.fromEntries(addons.flatMap((a) => Object.entries(a.commands ?? {}).map(([name, cmd]): [string, Command] => [name, (env, args) => cmd.run(env, args)])));

/** A command by name. Plain `table[name]` would find `constructor` and friends, so only own keys count. */
const lookup = (table: Record<string, Command>, name: string): Command | undefined => (Object.hasOwn(table, name) ? table[name] : undefined);

function banner(env: Env): void {
  const addons = env.addons.length ? `  ${c.dim('addons')} ${c.cyan(env.addons.map((a) => a.name).join(', '))}` : '';
  console.log(`\n${c.bold('n8n hosting lab')}  ${c.dim('provider')} ${c.cyan(env.provider.name)}${addons}\n`);
}

/** Connects to the cluster to work on, or says there is none. Stopped clusters are an error, not something to start. */
async function connect(env: Env, requested: string | undefined): Promise<boolean> {
  const found = await use(env.provider, requested);
  if (!found) return false;
  if (!found.running) throw new UserError(`Cluster ${found.name} is stopped. Start it with ./lab up --cluster ${found.name}`);
  await selectCluster(env, found.name);
  return true;
}

async function main(opts: Options): Promise<void> {
  const addons = await loadAddons([...opts.addons, ...(process.env.LAB_ADDONS?.split(':').filter(Boolean) ?? [])]);
  if (!opts.command || opts.help || opts.command === 'help') return console.log(helpText(addons));

  const env = envFromProcess(getProvider(opts.provider || process.env.LAB_PROVIDER || 'minikube'), addons, opts);
  banner(env);
  await requireClis(env.provider);

  const { command, args } = opts;
  const standalone = lookup(STANDALONE, command);
  if (standalone) return standalone(env, args, opts);

  const handler = lookup(ON_CLUSTER, command) ?? lookup(addonCommands(addons), command);
  if (!handler) throw new UserError(`Unknown command '${command}'. Run ./lab --help`);
  // Deleting the registry needs no cluster: it outlives them, and is often removed after the last one is gone.
  if (command === 'registry' && args[0] === 'delete') return handler(env, args, opts);
  if (!(await connect(env, opts.cluster))) {
    if (command === 'down') return console.log(c.dim(`No ${env.provider.name} cluster exists, nothing to remove.\n`));
    throw new UserError(`No ${env.provider.name} cluster exists. Create one with ./lab up`);
  }
  return handler(env, args, opts);
}

(async () => main(parseOptions()))().catch((e) => {
  console.error(`\n${c.red('✖')} ${e instanceof Error ? e.message : e}\n`);
  process.exit(1);
});
