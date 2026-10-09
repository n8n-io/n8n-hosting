import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { type Env, ROOT } from './kube.ts';
import type { Provider } from '../providers/index.ts';
import { UserError, ask, c, choose } from '../support/ui.ts';

// The cluster last used per provider, like kubectl's current context. Generated, so it is git-ignored.
const FILE = join(ROOT, '.lab-state.json');
type State = Record<string, string>;

const load = (): State => (existsSync(FILE) ? JSON.parse(readFileSync(FILE, 'utf8') || '{}') : {});
export const remember = (provider: Provider, name: string) => writeFileSync(FILE, JSON.stringify({ ...load(), [provider.name]: name }, null, 2));
export const forget = (provider: Provider, name: string) => {
  const state = load();
  if (state[provider.name] === name) delete state[provider.name];
  writeFileSync(FILE, JSON.stringify(state, null, 2));
};
export const current = (provider: Provider): string | undefined => load()[provider.name];

const normalize = (provider: Provider, name: string) => provider.normalize?.(name) ?? name;

/** For `up`: lists the clusters that exist and lets you pick one or create a new one. */
export async function pick(provider: Provider, flag?: string): Promise<{ name: string; isNew: boolean }> {
  const existing = await provider.list();
  const names = existing.map((e) => e.name);
  if (flag) {
    const name = normalize(provider, flag);
    return { name, isNew: !names.includes(name) };
  }
  if (!existing.length) return { name: provider.defaultName(), isNew: true };

  const saved = current(provider);
  const fallback = saved && names.includes(saved) ? saved : names[0];
  if (!process.stdin.isTTY) {
    if (names.length === 1 || fallback === saved) return { name: fallback, isNew: false };
    throw new UserError(`Several ${provider.name} clusters exist: ${names.join(', ')}. Pass one with --cluster <name>.`);
  }
  const options = [...existing.map((e) => `${e.name}${e.name === fallback ? c.dim('  (current)') : ''}  ${c.dim(e.detail ?? '')}`), c.green('Create a new cluster')];
  const index = await choose(`${provider.name} clusters`, options, names.indexOf(fallback));
  if (index < existing.length) return { name: names[index], isNew: false };
  return { name: normalize(provider, await ask('Name for the new cluster', provider.defaultName())), isNew: true };
}

/** For every other command: the cluster named by --cluster, else the current one, else the only one. */
export async function use(provider: Provider, flag?: string): Promise<{ name: string; running: boolean } | undefined> {
  const existing = await provider.list();
  if (!existing.length) return undefined;
  const name = flag ? normalize(provider, flag) : current(provider) && existing.some((e) => e.name === current(provider)) ? current(provider)! : existing.length === 1 ? existing[0].name : undefined;
  if (!name) throw new UserError(`Several ${provider.name} clusters exist: ${existing.map((e) => e.name).join(', ')}. Pass one with --cluster <name>.`);
  const found = existing.find((e) => e.name === name);
  if (!found) throw new UserError(`No ${provider.name} cluster named ${name}. See: ./lab clusters`);
  return found;
}

/** Makes a cluster the one every command talks to: sets its name and the kube context that reaches it. */
export async function selectCluster(env: Env, name: string): Promise<void> {
  env.cluster = name;
  env.ctx = await env.provider.connect(name);
}
