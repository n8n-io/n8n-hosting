import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { parse } from 'yaml';
import type { Env } from '../cluster/kube.ts';

/** Every file in the chart's examples/ folder is a target named example-<file>. */
export const EXAMPLE_PREFIX = 'example-';
export const isExample = (t: string) => t.startsWith(EXAMPLE_PREFIX);
const dir = (env: Env) => join(env.chart, 'examples');

export function listExamples(env: Env): string[] {
  try {
    return readdirSync(dir(env)).filter((f) => f.endsWith('.yaml')).map((f) => EXAMPLE_PREFIX + f.slice(0, -5));
  } catch {
    return [];
  }
}

export const exampleFile = (env: Env, t: string) => join(dir(env), `${t.slice(EXAMPLE_PREFIX.length)}.yaml`);

export type Values = Record<string, any>;
export const exampleValues = (env: Env, t: string): Values => parse(readFileSync(exampleFile(env, t), 'utf8')) ?? {};

/** An example that turns on multi-main or a licence cannot run without an Enterprise key. */
export const needsLicense = (values: Values) => !!(values.license?.enabled || values.multiMain?.enabled);

/** Every secret an example points at, with the keys it reads from each. */
export function secretsIn(values: Values): Map<string, Set<string>> {
  const found = new Map<string, Set<string>>();
  const add = (name: string, key: string) => found.set(name, (found.get(name) ?? new Set()).add(key));
  const walk = (node: unknown, parentKey: string) => {
    if (Array.isArray(node)) return node.forEach((n) => walk(n, parentKey));
    if (!node || typeof node !== 'object') return;
    const o = node as Values;
    if (typeof o.name === 'string' && typeof o.key === 'string' && /secret/i.test(parentKey)) add(o.name, o.key);
    if (typeof o.existingSecret === 'string' && typeof o.existingSecretKey === 'string') add(o.existingSecret, o.existingSecretKey);
    for (const [k, v] of Object.entries(o)) walk(v, k);
  };
  walk(values, '');
  return found;
}
