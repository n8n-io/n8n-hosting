import assert from 'node:assert/strict';
import { test } from 'node:test';
import { describeFailure, failedScopes, failures, recordFailure } from '../src/support/failures.ts';

test('a failure names its scope and step, and scopes are unique', () => {
  recordFailure('queue', 'Helm install');
  recordFailure('queue', 'Waiting for pods');
  recordFailure('k8s', 'Manifests');
  assert.equal(failures().length, 3);
  assert.deepEqual([...failedScopes()].sort(), ['k8s', 'queue']);
  assert.equal(describeFailure(failures()[0]), 'queue: Helm install');
});
