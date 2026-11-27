import type { ListrTask } from 'listr2';
import { type Values, exampleFile, exampleValues, needsLicense, secretsIn } from './chart-examples.ts';
import { type Env, ensureSecret, exists, kubectl } from '../cluster/kube.ts';
import { ensureNs } from '../cluster/namespaces.ts';
import { writeLabEnv } from '../cluster/settings.ts';
import { UserError } from '../support/ui.ts';
import { namespaceOf } from './names.ts';
import { ensureChartSecrets, helmInstall, hex, postgresAndRedis, reloadPods, step, waitForRollouts } from './steps.ts';

/** Secrets the lab already makes for every chart install. */
const SHARED_SECRETS = ['n8n-core-secrets', 'n8n-db-secret', 'n8n-license'];

type Labels = Record<string, string>;

/** True when some node carries every label in the selector. */
export const nodeMatches = (selector: Labels, nodes: Labels[]) => nodes.some((labels) => Object.entries(selector).every(([k, v]) => labels[k] === v));

/** Stops early with the fix, instead of waiting ten minutes for pods that can never start. */
async function checkPrerequisites(env: Env, values: Values): Promise<void> {
  if (values.keda?.enabled && !(await exists(env, 'crd', 'scaledobjects.keda.sh'))) {
    throw new UserError('This example needs KEDA, which is not installed. Install it first:\n  helm install keda kedacore/keda --namespace keda-system --create-namespace');
  }
  const selectors: Labels[] = Object.values<{ nodeSelector?: Labels } | undefined>(values.nodePlacement ?? {}).flatMap((p) => (p?.nodeSelector ? [p.nodeSelector] : []));
  if (!selectors.length) return;
  const nodes = (JSON.parse(await kubectl(env, ['get', 'nodes', '-o', 'json'])) as { items: { metadata: { labels?: Labels } }[] }).items.map((n) => n.metadata.labels ?? {});
  const unmet = selectors.find((sel) => !nodeMatches(sel, nodes));
  if (!unmet) return;
  const want = Object.entries(unmet).map(([k, v]) => `${k}=${v}`).join(',');
  throw new UserError(`This example needs a node labelled ${want}. Add a node and label it:\n  kubectl label node <node> ${want}`);
}

/**
 * A chart example as shipped, with common.yaml laid over it. That points the database and Redis at the lab's own,
 * shrinks resources and replicas, and sets the secrets every example shares. Secrets an example names that the lab
 * does not know get random values. Autoscalers are off so a small cluster is not asked for fifty workers.
 */
export function exampleSteps(env: Env, t: string): ListrTask[] {
  const ns = namespaceOf(t);
  const values = exampleValues(env, t);
  const licensed = needsLicense(values);
  let settingsChanged = false;
  const sets = [...(licensed ? ['license.enabled=true', 'license.existingSecret.name=n8n-license'] : []), ...['main', 'worker', 'webhookProcessor'].map((x) => `hpa.${x}.enabled=false`)];
  return [
    step('Prerequisites', () => checkPrerequisites(env, values)),
    step('Namespace', () => ensureNs(env, ns)),
    step('Secrets', async () => {
      await ensureChartSecrets(env, ns, licensed);
      for (const [name, keys] of secretsIn(values)) {
        if (!SHARED_SECRETS.includes(name)) await ensureSecret(env, ns, name, () => Object.fromEntries([...keys].map((k) => [k, hex(16)])));
      }
    }),
    step('Settings', async () => void (settingsChanged = (await writeLabEnv(env, ns, ns)) === 'configured')),
    ...(values.database?.type === 'sqlite' ? [] : [postgresAndRedis(env, ns)]),
    helmInstall(env, ns, [exampleFile(env, t)], sets),
    reloadPods(env, ns, () => settingsChanged),
    waitForRollouts(env, ns),
  ];
}
