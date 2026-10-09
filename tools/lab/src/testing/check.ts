import type { ListrTask } from 'listr2';
import { recordFailure } from '../support/failures.ts';
import { type Env, kubectl } from '../cluster/kube.ts';
import { isCompose, namespaceOf } from '../targets/index.ts';
import { type Exec, execFor, httpGet } from './exec.ts';
import { retry } from './retry.ts';

/** A check named `title`, for a target. It retries, and records its failure so the exit code tells the truth. */
export const checker = (target: string) => (title: string, fn: () => Promise<unknown>): ListrTask => ({
  title,
  task: async () => {
    try {
      await retry(fn);
    } catch (e) {
      recordFailure(target, title);
      throw e;
    }
  },
});

export async function expectStatus(exec: Exec, path: string, want: number, contains?: string): Promise<void> {
  const { status, body } = await httpGet(exec, path);
  if (status !== want) throw new Error(`GET ${path} returned ${status || 'no response'}, expected ${want}`);
  if (contains && !body.includes(contains)) throw new Error(`GET ${path} did not contain "${contains}"`);
}

/** The smoke tests for one target. */
export const checkTask = (env: Env, t: string): ListrTask => ({
  title: t,
  task: (_, task) => {
    const { main, webhook } = execFor(env, t);
    const check = checker(t);
    // The subfolder stack serves everything under a path prefix, so only health is checked there.
    const prefixed = t === 'compose-subfolder-with-ssl';
    return task.newListr(
      [
        ...(isCompose(t) ? [] : [check('Pods ready', () => kubectl(env, ['-n', namespaceOf(t), 'wait', '--for=condition=Available', 'deploy', '--all', '--timeout=30s']))]),
        check('Health', () => expectStatus(main, '/healthz', 200)),
        check('Readiness (database reachable)', () => expectStatus(main, '/healthz/readiness', 200)),
        ...(prefixed ? [] : [check('Editor loads', () => expectStatus(main, '/', 200, 'n8n')), check('Webhook route answers', () => expectStatus(webhook, '/webhook/lab-check', 404))]),
      ],
      { concurrent: false, exitOnError: false },
    );
  },
});
