import type { ListrTask } from 'listr2';
import { runTasks } from '../tasks.ts';
import { COMPOSE_TARGETS, checkTargets, clusterTargets, removeTargets } from '../targets/index.ts';
import { c } from '../ui.ts';
import type { Command } from './types.ts';

export const down: Command = async (env, args) => {
  const all = args.length === 0;
  const targets = all ? [...(await clusterTargets(env)), ...(env.provider.local ? COMPOSE_TARGETS : [])] : checkTargets(env, args);
  const removal: ListrTask = { title: `Remove ${all ? 'all targets' : targets.join(', ')}`, task: (_, task) => removeTargets(env, targets, (l) => (task.output = l)) };
  const addonCleanup = env.addons.filter((a) => a.afterDown).map((a): ListrTask => ({ title: `${a.name} (addon)`, task: (_, task) => a.afterDown!(env, all, (l) => (task.output = l)) }));
  await runTasks([removal, ...addonCleanup]);
  console.log(`\n${c.green('Removed.')}`);
  // Deployments are gone, but the cluster is not. Say so, because a cloud cluster keeps costing money.
  const delete_ = `./lab cluster delete ${env.cluster}`;
  if (env.provider.local) console.log(c.dim(`Cluster ${env.cluster} is still running. ${delete_} removes it.\n`));
  else console.log(`${c.yellow(`Cluster ${env.cluster} is still running and costing money.`)} ${c.dim(`Delete it with ${delete_}`)}\n`);
};
