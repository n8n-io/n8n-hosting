import type { ListrTask } from 'listr2';
import type { Env } from '../cluster/kube.ts';
import { ensureNs } from '../cluster/namespaces.ts';
import { writeLabEnv } from '../cluster/settings.ts';
import { namespaceOf } from './names.ts';
import { ensureChartSecrets, helmInstall, postgresAndRedis, step, waitForRollouts } from './steps.ts';

/** The Helm values that make each topology. Everything else comes from values/common.yaml. */
const TOPOLOGY: Record<string, string[]> = {
  single: ['queueMode.enabled=false', 'database.type=sqlite', 'database.useExternal=false', 'redis.enabled=false', 'persistence.enabled=true', 'persistence.size=1Gi', 'strategy.type=Recreate'],
  queue: [],
  webhooks: ['webhookProcessor.enabled=true'],
  multimain: ['webhookProcessor.enabled=true', 'multiMain.enabled=true', 'license.enabled=true', 'license.existingSecret.name=n8n-license'],
};

/** The Helm chart as one of its four topologies. */
export function chartSteps(env: Env, t: string): ListrTask[] {
  const ns = namespaceOf(t);
  return [
    step('Namespace', () => ensureNs(env, ns)),
    step('Secrets', () => ensureChartSecrets(env, ns, t === 'multimain')),
    step('Settings', () => writeLabEnv(env, ns, ns)),
    ...(t === 'single' ? [] : [postgresAndRedis(env, ns)]),
    helmInstall(env, ns, [], TOPOLOGY[t]),
    waitForRollouts(env, ns),
  ];
}
