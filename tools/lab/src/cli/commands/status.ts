import { type Env, kubectl } from '../../cluster/kube.ts';
import { labNamespaces } from '../../cluster/namespaces.ts';
import { COMPOSE_TARGETS, composeContainers } from '../../targets/index.ts';
import { c, table } from '../../support/ui.ts';
import type { Command } from './types.ts';

interface PodList {
  items: { metadata: { name: string }; status: { phase: string; containerStatuses?: { ready: boolean }[] } }[];
}

/** One row per pod: name, how many containers are ready, and the phase in a colour that says whether it is fine. */
async function podRows(env: Env, namespace: string): Promise<string[][]> {
  const { items } = JSON.parse(await kubectl(env, ['-n', namespace, 'get', 'pods', '-o', 'json'])) as PodList;
  return items.map((pod) => {
    const containers = pod.status.containerStatuses ?? [];
    const ready = containers.filter((s) => s.ready).length;
    const { phase } = pod.status;
    const colour = phase === 'Running' && ready === containers.length ? c.green : phase === 'Failed' ? c.red : c.yellow;
    return [pod.metadata.name, `${ready}/${containers.length}`, colour(phase)];
  });
}

const indented = (rows: string[][], header: string[]) => (rows.length ? table([header, ...rows]).replace(/^/gm, '  ') : c.dim('  no pods'));

/** Prints what is running: pods per namespace, then Compose containers. Returns false when there was nothing. */
async function printDeployments(env: Env): Promise<boolean> {
  let shown = false;
  for (const ns of (await labNamespaces(env, true)).sort()) {
    shown = true;
    console.log(c.bold(ns));
    console.log(indented(await podRows(env, ns), ['POD', 'READY', 'STATUS']) + '\n');
  }
  for (const t of env.provider.local ? COMPOSE_TARGETS : []) {
    const containers = await composeContainers(t);
    if (!containers.length) continue;
    shown = true;
    console.log(`${c.bold(t)} ${c.dim('(docker compose)')}`);
    console.log(indented(containers.map((x) => [x.name, (x.status.startsWith('Up') ? c.green : c.yellow)(x.status)]), ['CONTAINER', 'STATUS']) + '\n');
  }
  return shown;
}

export const status: Command = async (env) => {
  const info = await env.provider.info?.(env.cluster).catch(() => '');
  console.log(`${c.bold('cluster')} ${env.cluster} ${c.dim(info ?? '')}\n`);
  if (!(await printDeployments(env))) console.log(c.dim('Nothing deployed. Try ./lab up queue\n'));
};
