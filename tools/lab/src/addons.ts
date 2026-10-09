import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { type Env, ROOT, apply, exists, kubectl } from './cluster/kube.ts';
import { ensureNs, removeNamespaces } from './cluster/namespaces.ts';
import { run } from './support/sh.ts';
import { UserError, c, table } from './support/ui.ts';

type Log = (line: string) => void;

/**
 * An addon adds something to the lab without the lab knowing about it: extra n8n settings, extra things to deploy,
 * extra commands. Every hook is optional. Load one with `--addon <name|path>` or LAB_ADDONS=<a>:<b>.
 */
export interface Addon {
  name: string;
  /** Extra n8n settings for one target. `source` names the target, and `compose` says it runs in Docker, outside the cluster. */
  env?(ctx: { source: string; compose: boolean }): Record<string, string>;
  beforeUp?(env: Env, log: Log): Promise<void>;
  afterUp?(env: Env, targets: string[], log: Log): Promise<void>;
  /** `all` is true when `down` was run without a target. */
  afterDown?(env: Env, all: boolean, log: Log): Promise<void>;
  commands?: Record<string, { help: string; run(env: Env, args: string[]): Promise<void> }>;
}

/** What an addon may use from the lab. It is handed in, so an addon can live anywhere. */
export const labApi = { ROOT, kubectl, apply, ensureNs, exists, removeNamespaces, run, UserError, c, table };
export type LabApi = typeof labApi;

/** A bare name is addons/<name>/ in this repo. Anything with a slash, `.` or `~` is a path to a folder or a file. */
function locate(spec: string): string {
  if (!/[/\\]|^[.~]|\.[cm]?[jt]s$/.test(spec)) return join(ROOT, 'addons', spec, 'index.ts');
  const path = resolve(spec.replace(/^~/, homedir()));
  return /\.[cm]?[jt]s$/.test(path) ? path : join(path, 'index.ts');
}

export async function loadAddons(specs: string[]): Promise<Addon[]> {
  const addons: Addon[] = [];
  const loaded = new Set<string>();
  for (const spec of specs) {
    const path = locate(spec);
    if (loaded.has(path)) continue; // given twice, for example by --addon and LAB_ADDONS
    loaded.add(path);
    try {
      addons.push(await (await import(pathToFileURL(path).href)).default(labApi));
    } catch (e) {
      throw new UserError(`Addon '${spec}' could not be loaded: ${e instanceof Error ? e.message : e}`);
    }
  }
  return addons;
}
