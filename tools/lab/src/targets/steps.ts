import { randomBytes } from 'node:crypto';
import { join } from 'node:path';
import type { ListrTask } from 'listr2';
import { type Env, ROOT, ensureSecret, helm, kubectl } from '../kube.ts';
import { recordFailure } from '../failures.ts';
import { UserError } from '../ui.ts';

export type Log = (line: string) => void;

export const hex = (bytes: number) => randomBytes(bytes).toString('hex');

/** One named step, with a log function that writes to the line under its title. */
export const step = (title: string, fn: (log: Log) => Promise<unknown>): ListrTask => ({
  title,
  task: async (_, task) => void (await fn((line) => (task.output = line))),
});

/** Records a step's failure against its target, because listr2 will not fail the top-level run for a subtask. */
export const recorded = (target: string, steps: ListrTask[]): ListrTask[] =>
  steps.map((s) => ({
    ...s,
    task: async (ctx, task) => {
      try {
        return await (s.task as (ctx: unknown, task: unknown) => Promise<unknown>)(ctx, task);
      } catch (e) {
        recordFailure(target, String(s.title ?? 'step'));
        throw e;
      }
    },
  }));

/** Waits for each rollout, not just for Available: during an upgrade the old pod is still Available. */
export const waitForRollouts = (env: Env, ns: string): ListrTask =>
  step('Waiting for pods (the first image pull takes a few minutes)', async (log) => {
    const names = (await kubectl(env, ['-n', ns, 'get', 'deploy', '-o', 'name'])).split('\n').filter(Boolean);
    for (const name of names) await kubectl(env, ['-n', ns, 'rollout', 'status', name, '--timeout=10m'], { onLine: log });
  });

/** The keys every chart install reads. Random, and created once. The licence secret is only made when one is needed. */
export async function ensureChartSecrets(env: Env, ns: string, withLicense: boolean): Promise<void> {
  await ensureSecret(env, ns, 'n8n-core-secrets', () => ({ N8N_ENCRYPTION_KEY: hex(32), N8N_HOST: 'localhost', N8N_PORT: '5678', N8N_PROTOCOL: 'http' }));
  await ensureSecret(env, ns, 'n8n-db-secret', () => ({ password: hex(16) }));
  if (!withLicense) return;
  if (!env.licenseKey) throw new UserError('This target needs an Enterprise licence key. Set N8N_LICENSE_KEY.');
  await ensureSecret(env, ns, 'n8n-license', () => ({ 'license-key': env.licenseKey! }));
}

export const postgresAndRedis = (env: Env, ns: string): ListrTask =>
  step('Postgres and Redis', (log) => kubectl(env, ['-n', ns, 'apply', '-f', join(ROOT, 'manifests/postgres-redis.yaml')], { onLine: log }));

/** --set-string, so a comma or brace in a tag cannot add Helm values of its own. */
export const imageFlags = (env: Env): string[] => [
  ...(env.tag ? ['--set-string', `image.tag=${env.tag}`] : []),
  ...(env.image ? ['--set-string', `image.repository=${env.image}`, ...(env.provider.local ? ['--set', 'image.pullPolicy=Never'] : [])] : []),
];

/**
 * `helm upgrade --install` of the chart. Values go in this order, later wins: the files in `before` (an example),
 * the lab's common.yaml, --values files, then `sets` and the image flags.
 */
export const helmInstall = (env: Env, ns: string, before: string[], sets: string[]): ListrTask =>
  step('Helm install', (log) =>
    helm(
      env,
      [
        'upgrade', '--install', 'n8n', env.chart, '-n', ns,
        ...[...before, join(ROOT, 'values/common.yaml'), ...env.valuesFiles].flatMap((f) => ['-f', f]),
        ...sets.flatMap((s) => ['--set', s]),
        ...imageFlags(env),
      ],
      { onLine: log },
    ),
  );
