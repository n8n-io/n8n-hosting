import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { test } from 'node:test';

/**
 * Each folder under src/ is a layer, and a layer may only import from the layers listed here. Lower layers know
 * nothing about higher ones, so the lab can grow without turning into a knot. `import type` is exempt: it is erased
 * at runtime, so it creates no dependency.
 */
const MAY_IMPORT: Record<string, string[]> = {
  support: [],
  cluster: ['support'],
  providers: ['support'],
  targets: ['cluster', 'support'],
  testing: ['targets', 'cluster', 'support'],
  addons: ['cluster', 'support'], // src/addons.ts: the hooks an addon plugs into
  cli: ['testing', 'targets', 'providers', 'cluster', 'support', 'addons'],
};

const SRC = resolve(import.meta.dirname, '../src');
const layerOf = (file: string) => {
  const [first] = relative(SRC, file).split(sep);
  return first.endsWith('.ts') ? first.slice(0, -3) : first;
};

function sourceFiles(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? sourceFiles(join(dir, e.name)) : e.name.endsWith('.ts') ? [join(dir, e.name)] : []));
}

const RUNTIME_IMPORT = /^(?:import|export)\s(?!type\s).*\bfrom\s+['"](\.[^'"]+)['"]/;

test('every folder under src is a known layer', () => {
  for (const file of sourceFiles(SRC)) assert.ok(layerOf(file) in MAY_IMPORT, `${relative(SRC, file)} is in a folder that is not a known layer`);
});

test('a layer only imports from the layers below it', () => {
  const violations: string[] = [];
  for (const file of sourceFiles(SRC)) {
    const from = layerOf(file);
    for (const line of readFileSync(file, 'utf8').split('\n')) {
      const target = RUNTIME_IMPORT.exec(line)?.[1];
      if (!target) continue;
      const to = layerOf(resolve(dirname(file), target));
      if (to !== from && !MAY_IMPORT[from].includes(to)) violations.push(`${relative(SRC, file)} imports ${to} (${target})`);
    }
  }
  assert.deepEqual(violations, []);
});
