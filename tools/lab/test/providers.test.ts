import assert from 'node:assert/strict';
import { test } from 'node:test';
import { registryName, resourceGroup } from '../src/providers/aks.ts';
import { clusterConfig, friendly } from '../src/providers/eks.ts';
import { LAB_TAG, isLabTag, labName, runningFor } from '../src/providers/lab.ts';
import { getProvider } from '../src/providers/index.ts';
import { UserError } from '../src/support/ui.ts';

test('lab- prefix is added once', () => {
  assert.equal(labName('demo'), 'lab-demo');
  assert.equal(labName('lab-demo'), 'lab-demo');
});

test('both the current and the old lab tag are the lab\'s; nothing else is', () => {
  assert.ok(isLabTag(LAB_TAG));
  assert.ok(isLabTag('n8n-deployment-lab'));
  assert.ok(!isLabTag(''));
  assert.ok(!isLabTag('someone-elses'));
});

test('runningFor counts hours and minutes, and copes with a missing date', () => {
  const now = Date.parse('2026-01-01T10:00:00Z');
  assert.equal(runningFor('2026-01-01T06:55:00Z', now), 'running for 3h 5m');
  assert.equal(runningFor('', now), 'running for 0h 0m');
});

test('eksctl output is shortened to what a person waits for', () => {
  assert.match(friendly('2026-01-01 10:00:00 [i]  building cluster stack "eksctl-lab-cluster"'), /control plane/);
  assert.match(friendly('2026-01-01 10:00:00 [i]  building managed nodegroup stack'), /node group/);
  assert.equal(friendly('2026-01-01 10:00:00 [i]  something else'), 'something else');
});

test('the EKS config is tagged as the lab\'s and sized to the request', () => {
  const c = clusterConfig('lab-x', 'eu-west-1', 't3.large', 2);
  assert.equal(c.metadata.tags.lab, LAB_TAG);
  assert.equal(c.managedNodeGroups[0].desiredCapacity, 2);
  assert.equal(c.metadata.region, 'eu-west-1');
});

test('the Azure registry name is global-safe: no dashes, 6 characters of the subscription, at most 50 long', () => {
  assert.equal(registryName('a-b', '123456789'), 'labab123456');
  assert.equal(registryName('x'.repeat(80), 'abcdef').length, 50);
  assert.equal(resourceGroup('lab-x'), 'lab-x-rg');
});

test('an unknown provider lists the known ones', () => {
  assert.throws(() => getProvider('gcp'), (e: Error) => e instanceof UserError && /minikube, aws, azure/.test(e.message));
});

test('only minikube is shared and local', () => {
  assert.ok(getProvider('minikube').shared && getProvider('minikube').local);
  assert.ok(!getProvider('aws').shared && !getProvider('aws').local);
});
