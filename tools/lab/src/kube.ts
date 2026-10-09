import { join } from 'node:path';
import { existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { ok, run, type RunOpts } from './sh.ts';
import type { Provider } from './providers.ts';
import type { Addon } from './addons.ts';

export const ROOT = join(import.meta.dirname, '..');

export interface Env {
  provider: Provider;
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

export function envFromProcess(provider: Provider, addons: Addon[], extraEnv: Record<string, string>, valuesFiles: string[]): Env {
  // Inside n8n-hosting (tools/lab), the files to deploy are the ones around it.
  const here = join(ROOT, '../..');
  const hosting = process.env.HOSTING || (existsSync(join(here, 'charts/n8n')) ? here : join(homedir(), 'git/n8n-hosting'));
  return {
    provider,
    ctx: '',
    addons,
    extraEnv,
    valuesFiles,
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

export const apply = (env: Env, manifest: object | string, opts?: RunOpts) =>
  kubectl(env, ['apply', '-f', '-'], { ...opts, input: typeof manifest === 'string' ? manifest : JSON.stringify(manifest) });

export const exists = (env: Env, ...what: string[]) => ok('kubectl', ['--context', needCtx(env), 'get', ...what]);

/** Marks a namespace as the lab's. `down` and `status` only touch namespaces that carry it, whatever their name. */
export const LAB_LABEL = 'app.kubernetes.io/managed-by=n8n-hosting-lab';
const [LAB_KEY, LAB_VALUE] = LAB_LABEL.split('=');

const ADDON_KEY = 'n8n-hosting-lab/addon';

/** An addon's namespace passes its name, so it is not mistaken for a target. */
export const ensureNs = (env: Env, name: string, addon?: string) =>
  apply(env, { apiVersion: 'v1', kind: 'Namespace', metadata: { name, labels: { [LAB_KEY]: LAB_VALUE, ...(addon ? { [ADDON_KEY]: addon } : {}) } } });

/** The lab's namespaces. Addon namespaces are left out unless asked for. */
export async function labNamespaces(env: Env, includeAddons = false): Promise<string[]> {
  const { items } = JSON.parse(await kubectl(env, ['get', 'ns', '-l', LAB_LABEL, '-o', 'json']));
  return items.filter((n: any) => includeAddons || !n.metadata.labels?.[ADDON_KEY]).map((n: any) => n.metadata.name as string);
}

/** Created once, so a rerun never changes an encryption key under a running install. Values travel on stdin. */
export async function ensureSecret(env: Env, namespace: string, name: string, data: () => Record<string, string>) {
  if (await exists(env, '-n', namespace, 'secret', name)) return;
  await apply(env, { apiVersion: 'v1', kind: 'Secret', metadata: { name, namespace }, stringData: data() });
}

/** A cluster without a default storage class leaves every volume claim that names none Pending forever. */
export async function ensureDefaultStorageClass(env: Env, log: (line: string) => void) {
  const { items } = JSON.parse(await kubectl(env, ['get', 'sc', '-o', 'json']));
  const isDefault = (sc: any) => sc.metadata.annotations?.['storageclass.kubernetes.io/is-default-class'] === 'true';
  if (!items.length || items.some(isDefault)) return;
  const pick = items.find((sc: any) => sc.metadata.name === 'gp2') ?? items[0];
  log(`No default storage class, so ${pick.metadata.name} is now the default`);
  await kubectl(env, ['patch', 'sc', pick.metadata.name, '-p', JSON.stringify({ metadata: { annotations: { 'storageclass.kubernetes.io/is-default-class': 'true' } } })]);
}

/**
 * The n8n settings for one target: diagnostics off, so nothing reaches n8n's servers, then what addons add, then
 * what --env sets. `source` names the target.
 */
export const labEnv = (env: Env, source: string, compose = false): Record<string, string> => ({
  N8N_DIAGNOSTICS_ENABLED: 'false',
  ...Object.assign({}, ...env.addons.map((a) => a.env?.({ source, compose }) ?? {})),
  ...env.extraEnv,
});

/** The settings every n8n pod in a namespace reads. Always written, so the chart and manifests can rely on it. */
export const writeLabEnv = (env: Env, namespace: string, source: string) =>
  apply(env, { apiVersion: 'v1', kind: 'ConfigMap', metadata: { name: 'lab-env', namespace }, data: labEnv(env, source) });
