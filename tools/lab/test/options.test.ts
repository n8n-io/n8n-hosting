import assert from 'node:assert/strict';
import { test } from 'node:test';
import { parseEnvPairs, parseOptions } from '../src/options.ts';
import { UserError } from '../src/ui.ts';

test('--env pairs become a map, and a value may contain =', () => {
  assert.deepEqual(parseEnvPairs(['A=1', 'URL=http://x/?a=b']), { A: '1', URL: 'http://x/?a=b' });
});

test('--env without KEY=VALUE is a user error', () => {
  assert.throws(() => parseEnvPairs(['BAD']), UserError);
  assert.throws(() => parseEnvPairs(['=x']), UserError);
});

test('options: command, targets, flags', () => {
  const o = parseOptions(['up', 'queue', 'k8s', '--provider', 'aws', '--env', 'A=1', '--env', 'B=2', '-y', '--addon', './x']);
  assert.equal(o.command, 'up');
  assert.deepEqual(o.args, ['queue', 'k8s']);
  assert.equal(o.provider, 'aws');
  assert.deepEqual(o.env, { A: '1', B: '2' });
  assert.equal(o.yes, true);
  assert.deepEqual(o.addons, ['./x']);
});

test('options: nothing set means false and empty, not undefined', () => {
  const o = parseOptions(['check']);
  assert.equal(o.e2e, false);
  assert.deepEqual(o.env, {});
  assert.deepEqual(o.valuesFiles, []);
});

test('--values files are made absolute', () => {
  assert.ok(parseOptions(['up', '--values', 'my.yaml']).valuesFiles[0].startsWith('/'));
});
