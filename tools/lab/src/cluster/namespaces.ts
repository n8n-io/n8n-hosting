import { UserError } from '../support/ui.ts';
import { type Env, apply, kubectl } from './kube.ts';

/** Marks a namespace as the lab's. `down` and `status` only touch namespaces that carry it, whatever their name. */
export const LAB_LABEL = 'app.kubernetes.io/managed-by=n8n-hosting-lab';
const [LAB_KEY, LAB_VALUE] = LAB_LABEL.split('=');
const ADDON_KEY = 'n8n-hosting-lab/addon';

/** A namespace is the lab's only when it carries the lab's label. Anything else belongs to someone else. */
export const ownedByLab = (labels: Record<string, string> | undefined) => labels?.[LAB_KEY] === LAB_VALUE;

/**
 * Creates the namespace, labelled as the lab's. A namespace that already exists without the label is not ours, and
 * labelling it would let `down` delete it, so it is refused. An addon's namespace passes its name, so it is not
 * mistaken for a target.
 */
export async function ensureNs(env: Env, name: string, addon?: string): Promise<void> {
  const found = await kubectl(env, ['get', 'ns', name, '--ignore-not-found', '-o', 'json']);
  if (found.trim() && !ownedByLab(JSON.parse(found).metadata.labels)) {
    throw new UserError(`Namespace ${name} already exists and the lab did not create it, so it is left alone. The lab only manages namespaces it labelled itself: remove that namespace yourself, or use a different target name.`);
  }
  await apply(env, { apiVersion: 'v1', kind: 'Namespace', metadata: { name, labels: { [LAB_KEY]: LAB_VALUE, ...(addon ? { [ADDON_KEY]: addon } : {}) } } });
}

interface NamespaceList {
  items: { metadata: { name: string; labels?: Record<string, string> } }[];
}

/** The lab's namespaces. Addon namespaces are left out unless asked for. */
export async function labNamespaces(env: Env, includeAddons = false): Promise<string[]> {
  const { items } = JSON.parse(await kubectl(env, ['get', 'ns', '-l', LAB_LABEL, '-o', 'json'])) as NamespaceList;
  return items.filter((n) => includeAddons || !n.metadata.labels?.[ADDON_KEY]).map((n) => n.metadata.name);
}

interface PersistentVolumeList {
  items: { metadata: { name: string }; spec: { claimRef?: { namespace?: string } } }[];
}

/** Deletes namespaces and every trace of their data: leftover volumes, then the provider's disk folders. */
export async function removeNamespaces(env: Env, namespaces: string[], log: (line: string) => void): Promise<void> {
  // Only namespaces the lab labelled are deleted, so a namespace of yours that happens to be called lab-* is safe.
  const mine = new Set(await labNamespaces(env, true));
  for (const ns of namespaces.filter((n) => !mine.has(n))) log(`Skipping ${ns}: it is not labelled as the lab's`);
  const doomed = namespaces.filter((n) => mine.has(n));
  if (!doomed.length) return;
  await kubectl(env, ['delete', 'namespace', ...doomed, '--ignore-not-found'], { onLine: log });
  const { items } = JSON.parse(await kubectl(env, ['get', 'pv', '-o', 'json'])) as PersistentVolumeList;
  const left = items.filter((pv) => doomed.includes(pv.spec.claimRef?.namespace ?? '')).map((pv) => pv.metadata.name);
  if (left.length) await kubectl(env, ['delete', 'pv', ...left, '--ignore-not-found'], { onLine: log });
  await env.provider.wipeStorage?.(doomed, env.ctx);
}
