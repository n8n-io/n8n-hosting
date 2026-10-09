import assert from 'node:assert/strict';
import { test } from 'node:test';
import { storageClassToDefault } from '../src/cluster/kube.ts';
import { labEnv } from '../src/cluster/settings.ts';
import { fakeEnv } from './helpers.ts';

test('diagnostics are off by default', () => {
  assert.deepEqual(labEnv(fakeEnv(), 'lab-queue'), { N8N_DIAGNOSTICS_ENABLED: 'false' });
});

test('addons override the default, and --env overrides addons', () => {
  const addon = { name: 'a', env: ({ source, compose }: { source: string; compose: boolean }) => ({ N8N_DIAGNOSTICS_ENABLED: 'true', FROM: source, WHERE: compose ? 'docker' : 'cluster', X: 'addon' }) };
  const env = fakeEnv({ addons: [addon], extraEnv: { X: 'flag' } });
  assert.deepEqual(labEnv(env, 'lab-queue'), { N8N_DIAGNOSTICS_ENABLED: 'true', FROM: 'lab-queue', WHERE: 'cluster', X: 'flag' });
  assert.equal(labEnv(env, 'compose-x', true).WHERE, 'docker');
});

const sc = (name: string, isDefault = false) => ({ metadata: { name, annotations: isDefault ? { 'storageclass.kubernetes.io/is-default-class': 'true' } : undefined } });

test('a storage class is only made the default when the cluster has none, and gp2 is preferred', () => {
  assert.equal(storageClassToDefault([sc('gp3', true), sc('gp2')]), undefined);
  assert.equal(storageClassToDefault([sc('other'), sc('gp2')]), 'gp2');
  assert.equal(storageClassToDefault([sc('only')]), 'only');
});

test('a cluster with no storage class, or several and no clear choice, is an error and not a guess', () => {
  assert.throws(() => storageClassToDefault([]), /no storage class/);
  assert.throws(() => storageClassToDefault([sc('a'), sc('b')]), /several candidates \(a, b\)/);
});
