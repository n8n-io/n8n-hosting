import { randomUUID } from 'node:crypto';
import type { ListrTask } from 'listr2';
import type { Env } from './kube.ts';
import { check, execFor, get } from './check.ts';

/**
 * Runs inside the n8n container (it has node, not curl). The owner password comes from the install's own
 * encryption key, so no credential travels in an argument and a rerun logs in as the same owner.
 * Modes: "create" prints the id of an active webhook workflow, "remove <id>" deletes it.
 */
const SCRIPT = `
const fs = require('fs'), crypto = require('crypto');
const [mode, arg] = process.argv.slice(2);
const key = process.env.N8N_ENCRYPTION_KEY || fs.readFileSync('/home/node/.n8n/config', 'utf8');
const password = 'Lab1-' + crypto.createHash('sha256').update(key).digest('hex').slice(0, 16);
const email = 'lab-e2e@example.com';
const jar = '/tmp/lab-e2e.cookie';
let cookie = fs.existsSync(jar) ? fs.readFileSync(jar, 'utf8') : '';
const call = async (method, path, body) => {
  const r = await fetch('http://localhost:5678/rest' + path, { method, headers: { 'content-type': 'application/json', cookie }, body: body && JSON.stringify(body) });
  const set = r.headers.getSetCookie().map((c) => c.split(';')[0]).join('; ');
  if (set) fs.writeFileSync(jar, (cookie = set));
  const text = await r.text();
  if (!r.ok) throw new Error(method + ' ' + path + ' ' + r.status + ' ' + text.slice(0, 200));
  const json = text ? JSON.parse(text) : {};
  return json.data ?? json;
};
const login = () => call('POST', '/login', { emailOrLdapLoginId: email, email, password });
(async () => {
  // A saved cookie keeps retries from logging in again, which n8n rate-limits.
  const signedIn = cookie && (await call('GET', '/login').then(() => true, () => false));
  if (!signedIn) {
    cookie = '';
    await call('POST', '/owner/setup', { email, firstName: 'Lab', lastName: 'E2E', password }).catch(login);
    if (!cookie) await login();
  }
  const remove = async (id) => {
    await call('POST', '/workflows/' + id + '/archive').catch(() => {});
    await call('DELETE', '/workflows/' + id);
  };
  if (mode === 'remove') return void (await remove(arg));
  for (const old of await call('GET', '/workflows')) if (old.name === 'lab-e2e') await remove(old.id);
  const wf = await call('POST', '/workflows', {
    name: 'lab-e2e',
    nodes: [
      { id: '1', name: 'Webhook', type: 'n8n-nodes-base.webhook', typeVersion: 2, position: [0, 0], webhookId: crypto.randomUUID(), parameters: { httpMethod: 'GET', path: 'lab-e2e', responseMode: 'lastNode', options: {} } },
      { id: '2', name: 'Set', type: 'n8n-nodes-base.set', typeVersion: 3.4, position: [220, 0], parameters: { assignments: { assignments: [{ id: '1', name: 'answer', type: 'string', value: "={{ 'lab-' + $json.query.n }}" }] }, options: {} } },
    ],
    connections: { Webhook: { main: [[{ node: 'Set', type: 'main', index: 0 }]] } },
    settings: {},
  });
  await call('POST', '/workflows/' + wf.id + '/activate', { versionId: wf.versionId });
  console.log(wf.id);
})().catch((e) => { console.error(e.message); process.exit(1); });
`;
const encoded = Buffer.from(SCRIPT).toString('base64');
const node = (exec: (c: string) => Promise<string>, args: string) => exec(`echo ${encoded} | base64 -d > /tmp/lab-e2e.js && node /tmp/lab-e2e.js ${args}`);

/** The smoke checks, then: create a workflow, call its webhook, and see the answer it computed. */
export const e2eTask = (env: Env, t: string, smoke: ListrTask): ListrTask => ({
  title: t,
  task: (_, task) => {
    const { main, webhook } = execFor(env, t);
    let id = '';
    const nonce = randomUUID().slice(0, 8);
    return task.newListr(
      [
        { ...smoke, title: 'Smoke checks' },
        check('Create and activate a workflow', async () => void (id = (await node(main, 'create')).trim().split('\n').pop()!)),
        check('Webhook runs it and returns the result', async () => {
          const { status, body } = await get(webhook, `/webhook/lab-e2e?n=${nonce}`);
          if (status !== 200 || !body.includes(`lab-${nonce}`)) throw new Error(`webhook returned ${status || 'no response'} without the expected answer`);
        }),
        check('Remove the workflow', async () => void (id && (await node(main, `remove ${id}`)))),
      ],
      { concurrent: false, exitOnError: false },
    );
  },
});
