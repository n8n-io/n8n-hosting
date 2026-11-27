import type { ListrTask } from 'listr2';
import { exampleValues, isExample, needsLicense } from './chart-examples.ts';
import { type Env, exists } from '../cluster/kube.ts';
import { labNamespaces, removeNamespaces } from '../cluster/namespaces.ts';
import { chartSteps } from './chart.ts';
import { composeContainers, composeSteps, removeCompose } from './compose.ts';
import { exampleSteps } from './example.ts';
import { k8sSteps } from './k8s.ts';
import { COMPOSE_TARGETS, DESCRIPTION, isCompose, namespaceOf, targetOfNamespace } from './names.ts';
import { type Log, recorded } from './steps.ts';

export * from './names.ts';
export { composeContainers, composeProject } from './compose.ts';

function stepsFor(env: Env, t: string): ListrTask[] {
  if (isCompose(t)) return composeSteps(env, t);
  if (t === 'k8s') return k8sSteps(env);
  if (isExample(t)) return exampleSteps(env, t);
  return chartSteps(env, t);
}

const describe = (t: string) => (DESCRIPTION[t] ? `(${DESCRIPTION[t]})` : isExample(t) ? '(chart example)' : '');

/** Deploys one target. Each step records its own failure, so the run's exit code tells the truth. */
export const targetTask = (env: Env, t: string): ListrTask => ({
  title: `${t} ${describe(t)}`,
  task: (_, task) => task.newListr(recorded(t, stepsFor(env, t)), { concurrent: false, exitOnError: true }),
});

export async function removeTargets(env: Env, targets: string[], log: Log): Promise<void> {
  for (const t of targets.filter(isCompose)) await removeCompose(t, log);
  await removeNamespaces(env, targets.filter((t) => !isCompose(t)).map(namespaceOf), log);
}

/** Targets that need an Enterprise licence key: multi-main, and any example that turns on multi-main or a licence. */
export const licensed = (env: Env, t: string) => t === 'multimain' || (isExample(t) && needsLicense(exampleValues(env, t)));

export const hasLicenseSecret = (env: Env, t: string) => exists(env, '-n', namespaceOf(t), 'secret', 'n8n-license');

/** Cluster targets that exist right now, read from the lab's own namespaces. */
export async function clusterTargets(env: Env): Promise<string[]> {
  return (await labNamespaces(env)).filter((n) => n.startsWith('lab-')).map(targetOfNamespace);
}

/** Whether a target has anything deployed, even a stopped Compose stack, whose volumes a new install would reuse. */
export async function isDeployed(env: Env, t: string): Promise<boolean> {
  return isCompose(t) ? (await composeContainers(t)).length > 0 : (await clusterTargets(env)).includes(t);
}

/** Targets that are deployed right now: the lab's namespaces, and Compose stacks with a running container. */
export async function deployedTargets(env: Env): Promise<string[]> {
  const found = await clusterTargets(env);
  for (const t of COMPOSE_TARGETS) if ((await composeContainers(t)).some((c) => c.status.startsWith('Up'))) found.push(t);
  return found;
}
