import { current, forget } from '../clusters.ts';
import type { Env } from '../kube.ts';
import { runTasks } from '../tasks.ts';
import { UserError, ask, c, confirm, table } from '../ui.ts';
import type { Command } from './types.ts';

export const clusters: Command = async (env) => {
  const found = await env.provider.list();
  if (!found.length) return console.log(c.dim(`No ${env.provider.name} clusters. Create one with ./lab up\n`));
  const now = current(env.provider);
  console.log(table([['CLUSTER', 'STATE', 'CURRENT', 'DETAIL'], ...found.map((e) => [e.name, e.running ? c.green('running') : c.yellow('stopped'), e.name === now ? '*' : '', e.detail ?? ''])]) + '\n');
};

/** Deleting a cluster is the one irreversible thing the lab does, so it asks, and for a shared list it asks for the name. */
async function confirmDelete(env: Env, target: string, yes: boolean): Promise<void> {
  const { provider } = env;
  if (!yes && !(await confirm(`Delete the ${provider.name} cluster ${c.bold(target)} and everything in it?`))) throw new UserError('Cancelled. Pass --yes to skip this question.');
  // This list can hold your own clusters, so the name has to be typed, and --yes does not skip it.
  if (provider.shared && (await ask(`${provider.name} lists every cluster you have, not only the lab's. Type the name to confirm`, '')) !== target) {
    throw new UserError('The name did not match. Cancelled.');
  }
}

export const cluster: Command = async (env, args, opts) => {
  const [action, name] = args;
  if (action !== 'delete' || !name) throw new UserError('Usage: ./lab cluster delete <name>');
  const { provider } = env;
  const target = provider.normalize?.(name) ?? name;
  if (!(await provider.list()).some((e) => e.name === target)) throw new UserError(`No ${provider.name} cluster named ${target}. See: ./lab clusters`);
  await confirmDelete(env, target, opts.yes);
  await runTasks([{ title: `Delete ${provider.name} cluster ${target}`, task: (_, task) => provider.destroy(target, (l) => (task.output = l)) }]);
  forget(provider, target);
  console.log(`\n${c.green('Deleted.')}\n`);
};
