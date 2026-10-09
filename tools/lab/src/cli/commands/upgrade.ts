import { describeFailure, failures } from '../../support/failures.ts';
import { runTasks } from '../../support/tasks.ts';
import { upgradeTasks } from '../../testing/upgrade.ts';
import { checkTargets } from '../../targets/index.ts';
import { UserError, c } from '../../support/ui.ts';
import type { Command } from './types.ts';

export const upgrade: Command = async (env, args, opts) => {
  const [t] = checkTargets(env, args.slice(0, 1));
  if (!t || args.length > 1) throw new UserError('Pass one target: ./lab upgrade queue --from 2.39.0');
  if (!opts.from) throw new UserError('Pass the version to start from: --from <version>');
  // Each step needs the one before it, so the first failure stops the run.
  await runTasks(await upgradeTasks(env, t, opts.from, opts.to), { exitOnError: true });
  if (failures().length) throw new UserError(`Upgrade of ${t} failed: ${failures().map(describeFailure).join(', ')}`);
  console.log(`\n${c.green('Upgrade passed.')} ${c.dim(`./lab down ${t} removes it.`)}\n`);
};
