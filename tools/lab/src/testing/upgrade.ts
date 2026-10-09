import type { ListrTask } from 'listr2';
import type { Env } from '../cluster/kube.ts';
import { deployedTargets, targetTask } from '../targets/index.ts';
import { UserError } from '../support/ui.ts';
import { checkTask } from './check.ts';
import { execFor } from './exec.ts';

const MARKER = 'labmarker0001';

/**
 * Installs a target at one version, checks it, saves a workflow, upgrades to another version, and checks that
 * it still works and the workflow is still there. This is where real installs break: the database migrations.
 */
export async function upgradeTasks(env: Env, t: string, from: string, to?: string): Promise<ListrTask[]> {
  if ((await deployedTargets(env)).includes(t)) throw new UserError(`${t} is already deployed. Start from a clean install:  ./lab down ${t}`);
  const { main } = execFor(env, t);
  const old = { ...env, tag: from };
  const next = { ...env, tag: to };

  const version = (label: 'from' | 'to'): ListrTask => ({
    title: `n8n is ${label}`,
    task: async (_, task) => {
      const running = (await main('n8n --version')).trim().split('\n').pop()!;
      task.title = `n8n is ${running}`;
      const want = label === 'from' ? from : to;
      if (want && running !== want) throw new Error(`expected ${want}, got ${running}`);
    },
  });

  return [
    { ...targetTask(old, t), title: `Install ${from}` },
    version('from'),
    { ...checkTask(old, t), title: `Check ${from}` },
    {
      title: 'Save a marker workflow',
      task: () => main(`echo '{"id":"${MARKER}","name":"lab-upgrade-marker","nodes":[],"connections":{},"active":false}' > /tmp/marker.json && n8n import:workflow --input=/tmp/marker.json`),
    },
    { ...targetTask(next, t), title: `Upgrade to ${to ?? 'the shipped version'}` },
    version('to'),
    { ...checkTask(next, t), title: 'Check after upgrade' },
    {
      title: 'Marker workflow survived',
      task: async () => {
        if (!(await main('n8n list:workflow')).includes(MARKER)) throw new Error('The workflow saved before the upgrade is gone');
      },
    },
  ];
}
