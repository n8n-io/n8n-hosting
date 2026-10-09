import { runTasks } from '../tasks.ts';
import { UserError, c } from '../ui.ts';
import type { Command } from './types.ts';

export const registry: Command = async (env, args) => {
  const { registry } = env.provider;
  if (!registry) throw new UserError(`The ${env.provider.name} provider has no registry. Local clusters use images loaded into them.`);
  if (args[0] === 'delete') {
    await runTasks([{ title: 'Delete the registry', task: (_, task) => registry.remove(env.cluster, (l) => (task.output = l)) }]);
    return console.log(`\n${c.green('Deleted.')}\n`);
  }
  let repo = '';
  await runTasks([{ title: `Registry for ${env.provider.name} cluster ${env.cluster}`, task: async (_, task) => void (repo = await registry.ensure(env.cluster, (l) => (task.output = l))) }]);
  console.log(`\n${c.green('Ready.')} Build and push an image, then deploy it:\n  ${c.cyan(`REGISTRY=${repo} ./build-image.sh <worktree> <name>`)}\n  ${c.cyan(`N8N_IMAGE=${repo} N8N_TAG=<name> ./lab up <target> --provider ${env.provider.name}`)}\n`);
};
