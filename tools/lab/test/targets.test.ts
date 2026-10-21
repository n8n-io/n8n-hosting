import assert from 'node:assert/strict';
import { test } from 'node:test';
import { needsLicense, secretsIn } from '../src/targets/chart-examples.ts';
import { nodeMatches } from '../src/targets/example.ts';
import { composeOverride } from '../src/targets/compose.ts';
import { containerPatch, inLabNamespace, sized } from '../src/targets/k8s.ts';
import { ALL_TARGETS, checkTargets, mainDeployment, namespaceOf, targetOfNamespace } from '../src/targets/index.ts';
import { imageFlags } from '../src/targets/steps.ts';
import { isPrefixed } from '../src/testing/check.ts';
import { statusOf } from '../src/testing/exec.ts';
import { licenceKeyMissing } from '../src/testing/upgrade.ts';
import { isN8nDeployment } from '../src/targets/steps.ts';
import { ownedByLab } from '../src/cluster/namespaces.ts';
import { UserError } from '../src/support/ui.ts';
import { fakeEnv } from './helpers.ts';

test('a namespace and a target name map to each other', () => {
  assert.equal(namespaceOf('queue'), 'lab-queue');
  assert.equal(targetOfNamespace('lab-queue'), 'queue');
  assert.equal(mainDeployment('k8s'), 'n8n');
  assert.equal(mainDeployment('queue'), 'n8n-main');
});

test('Compose targets need the local provider', () => {
  assert.throws(() => checkTargets(fakeEnv({ local: false }), ['compose-caddy']), UserError);
  assert.deepEqual(checkTargets(fakeEnv({ local: true }), ['compose-caddy']), ['compose-caddy']);
  assert.throws(() => checkTargets(fakeEnv(), ['nope']), /Unknown target 'nope'/);
  assert.ok(ALL_TARGETS.includes('k8s'));
});

test('k8s manifests move from the n8n namespace to lab-k8s, including the database host', () => {
  const yaml = 'metadata:\n  namespace: n8n\nenv: db.n8n.svc.cluster.local\nother: not-namespace: n8nx';
  const out = inLabNamespace(yaml);
  assert.match(out, /namespace: lab-k8s/);
  assert.match(out, /db\.lab-k8s\.svc\.cluster\.local/);
});

const postgres = 'storage: 300Gi\nrequests:\n  cpu: "1"\n  memory: 2Gi\n';

test('the shipped Postgres is shrunk on a cloud and left alone locally', () => {
  assert.equal(sized(postgres, true), postgres);
  const small = sized(postgres, false);
  assert.match(small, /storage: 10Gi/);
  assert.match(small, /cpu: 100m/);
  assert.match(small, /memory: 512Mi/);
});

test('the n8n container patch carries the settings, a CPU limit with a request, and the image', () => {
  const plain = containerPatch(fakeEnv());
  assert.deepEqual(plain.envFrom, [{ configMapRef: { name: 'lab-env' } }]);
  assert.deepEqual(plain.resources, { requests: { cpu: '50m' }, limits: { cpu: '500m' } });
  assert.equal(plain.image, undefined);
  const local = containerPatch(fakeEnv({ image: 'n8n-mine', tag: 'latest' }));
  assert.equal(local.image, 'n8n-mine:latest');
  assert.equal(local.imagePullPolicy, 'Never');
  assert.equal(containerPatch(fakeEnv({ image: 'reg/n8n', tag: 'x', local: false })).imagePullPolicy, undefined);
});

test('image flags use --set-string so a comma cannot add values', () => {
  assert.deepEqual(imageFlags(fakeEnv({ tag: '1.0,replicaCount=0' })), ['--set-string', 'image.tag=1.0,replicaCount=0']);
  assert.deepEqual(imageFlags(fakeEnv()), []);
});

test('the Compose override only touches n8n and its worker, and quotes every value', () => {
  const yaml = composeOverride({ services: ['n8n', 'postgres', 'n8n-worker'], image: 'img:tag', neverPull: true, settings: { A: 'x: y', B: 'say "hi"' }, ownVolumes: false });
  assert.match(yaml, /^services:\n  n8n:\n/);
  assert.match(yaml, /  n8n-worker:\n/);
  assert.doesNotMatch(yaml, /postgres/);
  assert.match(yaml, /image: "img:tag"/);
  assert.match(yaml, /pull_policy: never/);
  assert.match(yaml, /- "A=x: y"/);
  assert.match(yaml, /- "B=say \\"hi\\""/);
  assert.equal(yaml.match(/ports: !override/g)?.length, 1); // only main frees its host port
  assert.doesNotMatch(yaml, /^volumes:/m);
});

test('the Caddy override makes its volumes ordinary', () => {
  assert.match(composeOverride({ services: ['n8n'], neverPull: false, settings: {}, ownVolumes: true }), /^volumes:\n  caddy_data: !override \{\}\n  n8n_data: !override \{\}\n$/m);
});

test('wget output gives the status, or 0 with no response', () => {
  assert.equal(statusOf('  HTTP/1.1 200 OK\n  Content-Type: x'), 200);
  assert.equal(statusOf('wget: bad address'), 0);
});

test('node selectors match only when one node has every label', () => {
  const nodes: Record<string, string>[] = [{ pool: 'a', zone: '1' }, { pool: 'b' }];
  assert.ok(nodeMatches({ pool: 'a' }, nodes));
  assert.ok(!nodeMatches({ pool: 'a', zone: '2' }, nodes));
  assert.ok(!nodeMatches({ pool: 'c' }, nodes));
});

test('an example that turns on a licence or multi-main needs a key', () => {
  assert.ok(needsLicense({ license: { enabled: true } }));
  assert.ok(needsLicense({ multiMain: { enabled: true } }));
  assert.ok(!needsLicense({ license: { enabled: false } }));
});

test('secrets an example names are found, with the keys it reads', () => {
  const found = secretsIn({ s3: { accessKeySecret: { name: 's3-secret', key: 'access' } }, a: { existingSecret: 'other', existingSecretKey: 'k' }, unrelated: { name: 'x', key: 'y' } }); // a name and key only count under a parent called ...secret
  assert.deepEqual([...(found.get('s3-secret') ?? [])], ['access']);
  assert.deepEqual([...(found.get('other') ?? [])], ['k']);
  assert.equal(found.has('x'), false);
});

test('only a namespace with the lab label is the lab\'s', () => {
  assert.ok(ownedByLab({ 'app.kubernetes.io/managed-by': 'n8n-hosting-lab' }));
  assert.ok(!ownedByLab({ 'app.kubernetes.io/managed-by': 'Helm' }));
  assert.ok(!ownedByLab({}));
  assert.ok(!ownedByLab(undefined));
});

test('a settings change restarts n8n\'s deployments and never Postgres or Redis', () => {
  for (const name of ['deployment.apps/n8n', 'deployment.apps/n8n-main', 'deployment.apps/n8n-worker', 'deployment.apps/n8n-webhook-processor']) assert.ok(isN8nDeployment(name), name);
  for (const name of ['deployment.apps/postgres', 'deployment.apps/redis', 'deployment.apps/n8nx', 'deployment.apps/collector']) assert.ok(!isN8nDeployment(name), name);
});

test('an upgrade of a licensed target needs a key, or a namespace that already holds one', () => {
  assert.ok(licenceKeyMissing(true, false, false));
  assert.ok(!licenceKeyMissing(true, true, false));
  assert.ok(!licenceKeyMissing(true, false, true));
  assert.ok(!licenceKeyMissing(false, false, false));
});

test('only the subfolder stack is served under a path prefix', () => {
  assert.ok(isPrefixed('compose-subfolder-with-ssl'));
  assert.ok(!isPrefixed('compose-caddy'));
});
