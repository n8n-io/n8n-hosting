import { listExamples } from '../chart-examples.ts';
import type { Env } from '../kube.ts';
import { UserError } from '../ui.ts';

export const CHART_TARGETS = ['single', 'queue', 'webhooks', 'multimain'];

/**
 * Where each Compose stack lives in n8n-hosting. `only` starts just those services, so a proxy (Caddy, Traefik)
 * never runs. `dataFolder` stacks need a DATA_FOLDER the lab creates and removes.
 */
export interface ComposeStack {
  dir: string;
  only?: string[];
  dataFolder?: boolean;
}

export const COMPOSE: Record<string, ComposeStack> = {
  'compose-with-postgres': { dir: 'docker-compose/withPostgres' },
  'compose-with-postgres-and-worker': { dir: 'docker-compose/withPostgresAndWorker' },
  'compose-caddy': { dir: 'docker-caddy', only: ['n8n'], dataFolder: true },
  'compose-subfolder-with-ssl': { dir: 'docker-compose/subfolderWithSSL', only: ['n8n'], dataFolder: true },
};

export const COMPOSE_TARGETS = Object.keys(COMPOSE);
export const ALL_TARGETS = [...CHART_TARGETS, 'k8s', ...COMPOSE_TARGETS];
export const DEFAULT_TARGETS = CHART_TARGETS;

export const DESCRIPTION: Record<string, string> = {
  single: 'Helm chart, one pod, SQLite',
  queue: 'Helm chart, main + 2 workers, Postgres, Redis',
  webhooks: 'queue + 2 webhook processors',
  multimain: 'webhooks + multi-main (Enterprise licence)',
  k8s: 'the kubernetes/ manifests',
  'compose-with-postgres': 'docker-compose/withPostgres',
  'compose-with-postgres-and-worker': 'docker-compose/withPostgresAndWorker',
  'compose-caddy': 'docker-caddy, n8n only',
  'compose-subfolder-with-ssl': 'docker-compose/subfolderWithSSL, n8n only',
};

export const isCompose = (t: string) => COMPOSE_TARGETS.includes(t);

/** The deployment that serves n8n's editor and API: the manifests call it n8n, the chart calls it n8n-main. */
export const mainDeployment = (t: string) => (t === 'k8s' ? 'n8n' : 'n8n-main');

const PREFIX = 'lab-';
export const namespaceOf = (t: string) => `${PREFIX}${t}`;
export const targetOfNamespace = (ns: string) => ns.slice(PREFIX.length);

/** Stops on a name the lab does not know, or a Compose target on a provider with no local Docker. */
export function checkTargets(env: Env, targets: string[]): string[] {
  for (const t of targets) {
    if (!ALL_TARGETS.includes(t) && !listExamples(env).includes(t)) throw new UserError(`Unknown target '${t}'. Targets: ${[...ALL_TARGETS, ...listExamples(env)].join(', ')}`);
    if (isCompose(t) && !env.provider.local) throw new UserError(`${t} runs on the local Docker, so it only works with the minikube provider.`);
  }
  return targets;
}
