import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import type { ListrTask } from 'listr2';
import { type Env, apply, kubectl } from '../kube.ts';
import { ensureNs } from '../namespaces.ts';
import { writeLabEnv } from '../settings.ts';
import { UserError } from '../ui.ts';
import { step, waitForRollouts } from './steps.ts';

const NAMESPACE = 'lab-k8s';

/** Moves the manifests from namespace n8n to lab-k8s, including the Postgres host name in the Deployment. */
export const inLabNamespace = (yaml: string) => yaml.replace(/^( *)namespace: n8n$/gm, `$1namespace: ${NAMESPACE}`).replaceAll('.n8n.svc.cluster.local', `.${NAMESPACE}.svc.cluster.local`);

/**
 * The shipped Postgres is sized for production: a 300 Gi claim, and requests of 1 CPU and 2 Gi. A one-node cloud
 * lab cannot fit that next to the cluster's own pods, so on a cloud the lab asks for 10 Gi, 100m and 512 Mi.
 */
export const sized = (yaml: string, local: boolean) =>
  local ? yaml : yaml.replaceAll('storage: 300Gi', 'storage: 10Gi').replace(/requests:\n(\s+)cpu: "1"\n\s+memory: 2Gi/, 'requests:\n$1cpu: 100m\n$1memory: 512Mi');

/**
 * What the lab merges into the n8n container of the shipped Deployment: its settings, the image, and a CPU limit
 * with a small request (a limit alone makes Kubernetes request the same amount). The manifest's memory settings stay.
 */
export function containerPatch(env: Pick<Env, 'image' | 'tag' | 'provider'>): Record<string, unknown> {
  const container: Record<string, unknown> = { name: 'n8n', envFrom: [{ configMapRef: { name: 'lab-env' } }], resources: { requests: { cpu: '50m' }, limits: { cpu: '500m' } } };
  if (env.image || env.tag) container.image = `${env.image ?? 'n8nio/n8n'}:${env.tag ?? 'latest'}`;
  if (env.image && env.provider.local) container.imagePullPolicy = 'Never';
  return container;
}

/** The kubernetes/ manifests as shipped, with the namespace changed so the lab never touches a real install. */
export function k8sSteps(env: Env): ListrTask[] {
  const dir = join(env.hosting, 'kubernetes');
  return [
    step('Namespace and settings', async () => {
      await ensureNs(env, NAMESPACE);
      await writeLabEnv(env, NAMESPACE, 'k8s');
    }),
    step('Manifests', async (log) => {
      let deployment: string;
      try {
        deployment = readFileSync(join(dir, 'n8n-deployment.yaml'), 'utf8');
      } catch {
        throw new UserError(`No kubernetes/n8n-deployment.yaml under HOSTING=${env.hosting}`);
      }
      const others = readdirSync(dir).filter((f) => f.endsWith('.yaml') && f !== 'namespace.yaml' && f !== 'n8n-deployment.yaml');
      for (const f of others) await apply(env, sized(inLabNamespace(readFileSync(join(dir, f), 'utf8')), env.provider.local), { onLine: log });
      const patch = JSON.stringify({ spec: { template: { spec: { containers: [containerPatch(env)] } } } });
      const patched = await kubectl(env, ['patch', '--local', '-f', '-', '-o', 'yaml', '-p', patch], { input: inLabNamespace(deployment) });
      await apply(env, patched, { onLine: log });
    }),
    waitForRollouts(env, NAMESPACE),
  ];
}
