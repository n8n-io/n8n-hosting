import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import type { ListrTask } from 'listr2';
import type { Env } from '../cluster/kube.ts';
import { checker } from './check.ts';
import { type Exec, execFor, httpGet } from './exec.ts';

const CLIENT = Buffer.from(readFileSync(new URL('./e2e-client.js', import.meta.url))).toString('base64');

/** Copies the client into the container and runs it. */
const runClient = (exec: Exec, args: string) => exec(`echo ${CLIENT} | base64 -d > /tmp/lab-e2e.js && node /tmp/lab-e2e.js ${args}`);

/** The smoke checks, then: create a workflow, call its webhook, and see the answer it computed. */
export const e2eTask = (env: Env, t: string, smoke: ListrTask): ListrTask => ({
  title: t,
  task: (_, task) => {
    const { main, webhook } = execFor(env, t);
    const check = checker(t);
    const nonce = randomUUID().slice(0, 8);
    let id = '';
    return task.newListr(
      [
        { ...smoke, title: 'Smoke checks' },
        check('Create and activate a workflow', async () => void (id = (await runClient(main, 'create')).trim().split('\n').pop()!)),
        check('Webhook runs it and returns the result', async () => {
          const { status, body } = await httpGet(webhook, `/webhook/lab-e2e?n=${nonce}`);
          if (status !== 200 || !body.includes(`lab-${nonce}`)) throw new Error(`webhook returned ${status || 'no response'} without the expected answer`);
        }),
        check('Remove the workflow', async () => void (id && (await runClient(main, `remove ${id}`)))),
      ],
      { concurrent: false, exitOnError: false },
    );
  },
});
