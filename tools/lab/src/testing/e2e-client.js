// Runs INSIDE the n8n container, which has node but not curl. The lab copies it there and calls it as
//   node e2e-client.js create          creates an active webhook workflow and prints its id
//   node e2e-client.js remove <id>     deletes it
// The owner's password comes from the install's own encryption key, so no credential travels in an argument,
// and a rerun signs in as the same owner.
const fs = require('fs');
const crypto = require('crypto');

const [mode, workflowId] = process.argv.slice(2);
const BASE = 'http://localhost:5678/rest';
const EMAIL = 'lab-e2e@example.com';
const COOKIE_FILE = '/tmp/lab-e2e.cookie';
const WORKFLOW_NAME = 'lab-e2e';

const encryptionKey = process.env.N8N_ENCRYPTION_KEY || fs.readFileSync('/home/node/.n8n/config', 'utf8');
const PASSWORD = 'Lab1-' + crypto.createHash('sha256').update(encryptionKey).digest('hex').slice(0, 16);

let cookie = fs.existsSync(COOKIE_FILE) ? fs.readFileSync(COOKIE_FILE, 'utf8') : '';

/** One call to n8n's REST API. Keeps the session cookie, and returns the `data` of the reply when it has one. */
async function call(method, path, body) {
  const res = await fetch(BASE + path, { method, headers: { 'content-type': 'application/json', cookie }, body: body && JSON.stringify(body) });
  const set = res.headers.getSetCookie().map((c) => c.split(';')[0]).join('; ');
  if (set) fs.writeFileSync(COOKIE_FILE, (cookie = set));
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${path} ${res.status} ${text.slice(0, 200)}`);
  const json = text ? JSON.parse(text) : {};
  return json.data ?? json;
}

const login = () => call('POST', '/login', { emailOrLdapLoginId: EMAIL, email: EMAIL, password: PASSWORD });

/** A saved cookie keeps retries from logging in again, which n8n rate-limits. */
async function signIn() {
  if (cookie && (await call('GET', '/login').then(() => true, () => false))) return;
  cookie = '';
  await call('POST', '/owner/setup', { email: EMAIL, firstName: 'Lab', lastName: 'E2E', password: PASSWORD }).catch(login);
  if (!cookie) await login();
}

async function removeWorkflow(id) {
  await call('POST', `/workflows/${id}/archive`).catch(() => {});
  await call('DELETE', `/workflows/${id}`);
}

/** A webhook that answers with what a Set node computes from the query, so a reply proves the workflow ran. */
async function createWebhookWorkflow() {
  for (const old of await call('GET', '/workflows')) if (old.name === WORKFLOW_NAME) await removeWorkflow(old.id);
  const workflow = await call('POST', '/workflows', {
    name: WORKFLOW_NAME,
    nodes: [
      { id: '1', name: 'Webhook', type: 'n8n-nodes-base.webhook', typeVersion: 2, position: [0, 0], webhookId: crypto.randomUUID(), parameters: { httpMethod: 'GET', path: 'lab-e2e', responseMode: 'lastNode', options: {} } },
      { id: '2', name: 'Set', type: 'n8n-nodes-base.set', typeVersion: 3.4, position: [220, 0], parameters: { assignments: { assignments: [{ id: '1', name: 'answer', type: 'string', value: "={{ 'lab-' + $json.query.n }}" }] }, options: {} } },
    ],
    connections: { Webhook: { main: [[{ node: 'Set', type: 'main', index: 0 }]] } },
    settings: {},
  });
  await call('POST', `/workflows/${workflow.id}/activate`, { versionId: workflow.versionId });
  return workflow.id;
}

(async () => {
  await signIn();
  if (mode === 'remove') return removeWorkflow(workflowId);
  console.log(await createWebhookWorkflow());
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
