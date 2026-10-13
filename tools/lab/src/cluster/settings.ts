import { type Env, apply } from './kube.ts';

/**
 * The n8n settings for one target: diagnostics off, so nothing reaches n8n's servers, then what addons add, then
 * what --env sets. `source` names the target, and `compose` says it runs in Docker, outside the cluster.
 */
export const labEnv = (env: Env, source: string, compose = false): Record<string, string> => ({
  N8N_DIAGNOSTICS_ENABLED: 'false',
  ...Object.assign({}, ...env.addons.map((a) => a.env?.({ source, compose }) ?? {})),
  ...env.extraEnv,
});

export type Applied = 'created' | 'configured' | 'unchanged';

/** What `kubectl apply` did, from its one line of output ("configmap/lab-env configured"). */
export const appliedAs = (output: string): Applied => (/\bconfigured\b/.test(output) ? 'configured' : /\bcreated\b/.test(output) ? 'created' : 'unchanged');

/**
 * The settings every n8n pod in a namespace reads. Always written, so the chart and manifests can rely on them.
 * Says whether they changed, because pods only read them when they start.
 */
export async function writeLabEnv(env: Env, namespace: string, source: string): Promise<Applied> {
  return appliedAs(await apply(env, { apiVersion: 'v1', kind: 'ConfigMap', metadata: { name: 'lab-env', namespace }, data: labEnv(env, source) }));
}
