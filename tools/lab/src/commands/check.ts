import { describeFailure, failures } from '../failures.ts';
import { runTasks } from '../tasks.ts';
import { checkTask } from '../testing/check.ts';
import { e2eTask } from '../testing/e2e.ts';
import { checkTargets, deployedTargets } from '../targets/index.ts';
import { UserError, c } from '../ui.ts';
import type { Command } from './types.ts';

export const check: Command = async (env, args, opts) => {
  const targets = args.length ? checkTargets(env, args) : await deployedTargets(env);
  if (!targets.length) throw new UserError('Nothing is deployed. Try ./lab up queue');
  await runTasks(targets.map((t) => (opts.e2e ? e2eTask(env, t, checkTask(env, t)) : checkTask(env, t))));
  if (failures().length) throw new UserError(`${failures().length} check${failures().length > 1 ? 's' : ''} failed: ${failures().map(describeFailure).join(', ')}`);
  console.log(`\n${c.green('All checks passed.')}\n`);
};
