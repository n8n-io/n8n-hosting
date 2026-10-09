import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import type { Addon } from './addons.ts';
import type { Options } from './options.ts';
import type { Provider } from './providers/types.ts';
import { ok, run, type RunOpts } from './sh.ts';

export const ROOT = join(import.meta.dirname, '..');

/** Everything a command needs to know: where it runs, what to deploy from, and which cluster it is talking to. */
export interface Env {
  provider: Provider;
  /** The selected cluster's name, and the kube context that reaches it. Both stay empty until a cluster is chosen. */
  cluster: string;
  ctx: string;
  addons: Addon[];
  /** Extra n8n settings from --env, applied to every target. */
  extraEnv: Record<string, string>;
  /** Extra Helm values files from --values, laid over the lab's own. */
  valuesFiles: string[];
  hosting: string;
  chart: string;
  image?: string;
  tag?: string;
  licenseKey?: string;
}

/** Inside n8n-hosting (tools/lab) the files to deploy are the ones around the lab. */
function defaultHosting(): string {
  const around = join(ROOT, '../..');
  return existsSync(join(around, 'charts/n8n')) ? around : join(homedir(), 'git/n8n-hosting');
}

export function envFromProcess(provider: Provider, addons: Addon[], opts: Pick<Options, 'env' | 'valuesFiles'>): Env {
  const hosting = process.env.HOSTING || defaultHosting();
  return {
    provider,
    cluster: '',
    ctx: '',
    addons,
    extraEnv: opts.env,
    valuesFiles: opts.valuesFiles,
    hosting,
    chart: process.env.CHART || join(hosting, 'charts/n8n'),
    image: process.env.N8N_IMAGE || undefined,
    tag: process.env.N8N_TAG || undefined,
    licenseKey: process.env.N8N_LICENSE_KEY || undefined,
  };
}

// An empty context would make kubectl and helm use whatever cluster is current, which may not be the lab's.
const needCtx = (env: Env) => {
  if (!env.ctx) throw new Error('No cluster selected. Refusing to run kubectl or helm against the current context.');
  return env.ctx;
};

export const kubectl = (env: Env, args: string[], opts?: RunOpts) => run('kubectl', ['--context', needCtx(env), ...args], opts);
export const helm = (env: Env, args: string[], opts?: RunOpts) => run('helm', ['--kube-context', needCtx(env), ...args], opts);
export const exists = (env: Env, ...what: string[]) => ok('kubectl', ['--context', needCtx(env), 'get', ...what]);

/** Applies a manifest, an object or YAML text, on stdin. */
export const apply = (env: Env, manifest: object | string, opts?: RunOpts) =>
  kubectl(env, ['apply', '-f', '-'], { ...opts, input: typeof manifest === 'string' ? manifest : JSON.stringify(manifest) });

/** Created once, so a rerun never changes an encryption key under a running install. Values travel on stdin. */
export async function ensureSecret(env: Env, namespace: string, name: string, data: () => Record<string, string>): Promise<void> {
  if (await exists(env, '-n', namespace, 'secret', name)) return;
  await apply(env, { apiVersion: 'v1', kind: 'Secret', metadata: { name, namespace }, stringData: data() });
}

const DEFAULT_CLASS = 'storageclass.kubernetes.io/is-default-class';

interface StorageClass {
  metadata: { name: string; annotations?: Record<string, string> };
}

/** The class to make the default, or nothing when the cluster already has one or has no class at all. Prefers gp2. */
export function storageClassToDefault(classes: StorageClass[]): string | undefined {
  if (!classes.length || classes.some((sc) => sc.metadata.annotations?.[DEFAULT_CLASS] === 'true')) return undefined;
  return (classes.find((sc) => sc.metadata.name === 'gp2') ?? classes[0]).metadata.name;
}

/** A cluster without a default storage class leaves every volume claim that names none Pending forever. */
export async function ensureDefaultStorageClass(env: Env, log: (line: string) => void): Promise<void> {
  const { items } = JSON.parse(await kubectl(env, ['get', 'sc', '-o', 'json'])) as { items: StorageClass[] };
  const name = storageClassToDefault(items);
  if (!name) return;
  log(`No default storage class, so ${name} is now the default`);
  await kubectl(env, ['patch', 'sc', name, '-p', JSON.stringify({ metadata: { annotations: { [DEFAULT_CLASS]: 'true' } } })]);
}
