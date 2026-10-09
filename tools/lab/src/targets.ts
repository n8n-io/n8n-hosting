import { randomBytes } from 'node:crypto';
import { mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import type { ListrTask } from 'listr2';
import { type Env, ROOT, apply, ensureNs, ensureSecret, exists, helm, kubectl, labEnv, labNamespaces, writeLabEnv } from './kube.ts';
import { ok, run } from './sh.ts';
import { UserError } from './ui.ts';
import { exampleFile, exampleValues, isExample, listExamples, needsLicense, secretsIn } from './examples.ts';

export const CHART_TARGETS = ['single', 'queue', 'webhooks', 'multimain'];

/**
 * Where each Compose stack lives in n8n-hosting. `only` starts just those services, so a proxy (Caddy, Traefik)
 * never runs. `dataFolder` stacks need a DATA_FOLDER the lab creates and removes.
 */
const COMPOSE: Record<string, { dir: string; only?: string[]; dataFolder?: boolean }> = {
  'compose-with-postgres': { dir: 'docker-compose/withPostgres' },
  'compose-with-postgres-and-worker': { dir: 'docker-compose/withPostgresAndWorker' },
  'compose-caddy': { dir: 'docker-caddy', only: ['n8n'], dataFolder: true },
  'compose-subfolder-with-ssl': { dir: 'docker-compose/subfolderWithSSL', only: ['n8n'], dataFolder: true },
};
export const COMPOSE_TARGETS = Object.keys(COMPOSE);
export const ALL_TARGETS = [...CHART_TARGETS, 'k8s', ...COMPOSE_TARGETS];
export const DEFAULT_TARGETS = CHART_TARGETS;

export const isCompose = (t: string) => COMPOSE_TARGETS.includes(t);
export const namespaceOf = (t: string) => (t === 'k8s' ? 'lab-k8s' : `lab-${t}`);

export const DESCRIPTION: Record<string, string> = {
  single: 'Helm chart, one pod, SQLite',
  queue: 'Helm chart, main + 2 workers, Postgres, Redis',
  webhooks: 'queue + 2 webhook processors',
  multimain: 'webhooks + multi-main (Enterprise licence)',
  k8s: 'the kubernetes/ manifests',
  'compose-with-postgres': 'docker-compose/withPostgres',
  'compose-with-postgres-and-worker': 'docker-compose/withPostgresAndWorker',
  'compose-caddy': 'docker-caddy, n8n only',
  'compose-subfolder-with-ssl': 'docker-compose/subfolderWithSSL, n8n only',
};

const CHART_FLAGS: Record<string, string[]> = {
  single: ['queueMode.enabled=false', 'database.type=sqlite', 'database.useExternal=false', 'redis.enabled=false', 'persistence.enabled=true', 'persistence.size=1Gi', 'strategy.type=Recreate'],
  queue: [],
  webhooks: ['webhookProcessor.enabled=true'],
  multimain: ['webhookProcessor.enabled=true', 'multiMain.enabled=true', 'license.enabled=true', 'license.existingSecret.name=n8n-license'],
};

export function checkTargets(env: Env, targets: string[]) {
  for (const t of targets) {
    if (!ALL_TARGETS.includes(t) && !listExamples(env).includes(t)) throw new UserError(`Unknown target '${t}'. Targets: ${[...ALL_TARGETS, ...listExamples(env)].join(', ')}`);
    if (isCompose(t) && !env.provider.local) throw new UserError(`${t} runs on the local Docker, so it only works with the minikube provider.`);
  }
}

type Log = (line: string) => void;
const step = (title: string, fn: (log: Log) => Promise<unknown>): ListrTask => ({
  title,
  task: async (_, task) => void (await fn((line) => (task.output = line))),
});

/** Steps that failed, as "target: step". Subtask failures do not reach the top-level run, so they are counted here. */
export const failures: string[] = [];

const recorded = (t: string, steps: ListrTask[]): ListrTask[] =>
  steps.map((s) => ({
    ...s,
    task: async (ctx, task) => {
      try {
        return await (s.task as (ctx: unknown, task: unknown) => Promise<unknown>)(ctx, task);
      } catch (e) {
        failures.push(`${t}: ${s.title}`);
        throw e;
      }
    },
  }));

export const targetTask = (env: Env, t: string): ListrTask => ({
  title: `${t} ${DESCRIPTION[t] ? `(${DESCRIPTION[t]})` : isExample(t) ? '(chart example)' : ''}`,
  task: (_, task) => task.newListr(recorded(t, isCompose(t) ? composeSteps(env, t) : t === 'k8s' ? k8sSteps(env) : isExample(t) ? exampleSteps(env, t) : chartSteps(env, t)), { concurrent: false, exitOnError: true }),
});

// Waits for each rollout, not just for Available: during an upgrade the old pod is still Available.
const wait = (env: Env, ns: string): ListrTask =>
  step('Waiting for pods (the first image pull takes a few minutes)', async (log) => {
    const names = (await kubectl(env, ['-n', ns, 'get', 'deploy', '-o', 'name'])).split('\n').filter(Boolean);
    for (const name of names) await kubectl(env, ['-n', ns, 'rollout', 'status', name, '--timeout=10m'], { onLine: log });
  });

const imageFlags = (env: Env) => [
  // --set-string, so a comma or brace in a tag cannot add Helm values of its own.
  ...(env.tag ? ['--set-string', `image.tag=${env.tag}`] : []),
  ...(env.image ? ['--set-string', `image.repository=${env.image}`, ...(env.provider.local ? ['--set', 'image.pullPolicy=Never'] : [])] : []),
];

/** Values files from --values go last, so they win. */
const valuesFlags = (env: Env) => env.valuesFiles.flatMap((f) => ['-f', f]);

function chartSteps(env: Env, t: string): ListrTask[] {
  const ns = namespaceOf(t);
  const hex = (n: number) => randomBytes(n).toString('hex');
  return [
    step('Namespace', () => ensureNs(env, ns)),
    step('Secrets', async () => {
      await ensureSecret(env, ns, 'n8n-core-secrets', () => ({ N8N_ENCRYPTION_KEY: hex(32), N8N_HOST: 'localhost', N8N_PORT: '5678', N8N_PROTOCOL: 'http' }));
      await ensureSecret(env, ns, 'n8n-db-secret', () => ({ password: hex(16) }));
      if (t === 'multimain') await ensureSecret(env, ns, 'n8n-license', () => ({ 'license-key': env.licenseKey! }));
    }),
    step('Settings', () => writeLabEnv(env, ns, ns)),
    ...(t === 'single' ? [] : [step('Postgres and Redis', (log) => kubectl(env, ['-n', ns, 'apply', '-f', join(ROOT, 'manifests/postgres-redis.yaml')], { onLine: log }))]),
    step('Helm install', (log) =>
      helm(env, ['upgrade', '--install', 'n8n', env.chart, '-n', ns, '-f', join(ROOT, 'values/common.yaml'), ...valuesFlags(env), ...CHART_FLAGS[t].flatMap((f) => ['--set', f]), ...imageFlags(env)], { onLine: log }),
    ),
    wait(env, ns),
  ];
}

/**
 * A chart example as shipped, with common.yaml laid over it. That points the database and Redis at the lab's own,
 * shrinks resources and replicas, and sets the secrets every example shares. Secrets an example names that the lab
 * does not know get random values. Autoscalers are off so a small cluster is not asked for fifty workers.
 */
function exampleSteps(env: Env, t: string): ListrTask[] {
  const ns = namespaceOf(t);
  const values = exampleValues(env, t);
  const hex = (n: number) => randomBytes(n).toString('hex');
  const shared = ['n8n-core-secrets', 'n8n-db-secret', 'n8n-license'];
  return [
    // Stop early with the fix, instead of waiting ten minutes for pods that can never start.
    step('Prerequisites', async () => {
      if (values.keda?.enabled && !(await exists(env, 'crd', 'scaledobjects.keda.sh'))) {
        throw new UserError('This example needs KEDA, which is not installed. Install it first:\n  helm install keda kedacore/keda --namespace keda-system --create-namespace');
      }
      const selectors: Record<string, string>[] = Object.values(values.nodePlacement ?? {}).map((p: any) => p?.nodeSelector).filter(Boolean);
      if (selectors.length) {
        const nodes: Record<string, string>[] = JSON.parse(await kubectl(env, ['get', 'nodes', '-o', 'json'])).items.map((n: any) => n.metadata.labels ?? {});
        for (const sel of selectors.filter((sel) => !nodes.some((labels) => Object.entries(sel).every(([k, v]) => labels[k] === v)))) {
          const want = Object.entries(sel).map(([k, v]) => `${k}=${v}`).join(',');
          throw new UserError(`This example needs a node labelled ${want}. Add a node and label it:\n  kubectl label node <node> ${want}`);
        }
      }
    }),
    step('Namespace', () => ensureNs(env, ns)),
    step('Secrets', async () => {
      await ensureSecret(env, ns, 'n8n-core-secrets', () => ({ N8N_ENCRYPTION_KEY: hex(32), N8N_HOST: 'localhost', N8N_PORT: '5678', N8N_PROTOCOL: 'http' }));
      await ensureSecret(env, ns, 'n8n-db-secret', () => ({ password: hex(16) }));
      if (needsLicense(values)) await ensureSecret(env, ns, 'n8n-license', () => ({ 'license-key': env.licenseKey! }));
      for (const [name, keys] of secretsIn(values)) {
        if (!shared.includes(name)) await ensureSecret(env, ns, name, () => Object.fromEntries([...keys].map((k) => [k, hex(16)])));
      }
    }),
    step('Settings', () => writeLabEnv(env, ns, ns)),
    ...(values.database?.type === 'sqlite' ? [] : [step('Postgres and Redis', (log) => kubectl(env, ['-n', ns, 'apply', '-f', join(ROOT, 'manifests/postgres-redis.yaml')], { onLine: log }))]),
    step('Helm install', (log) => {
      const licence = needsLicense(values) ? ['license.enabled=true', 'license.existingSecret.name=n8n-license'] : [];
      const noAutoscaling = ['main', 'worker', 'webhookProcessor'].map((x) => `hpa.${x}.enabled=false`);
      return helm(env, ['upgrade', '--install', 'n8n', env.chart, '-n', ns, '-f', exampleFile(env, t), '-f', join(ROOT, 'values/common.yaml'), ...valuesFlags(env), ...[...licence, ...noAutoscaling].flatMap((f) => ['--set', f]), ...imageFlags(env)], { onLine: log });
    }),
    wait(env, ns),
  ];
}

/** Moves the manifests from namespace n8n to lab-k8s, including the Postgres host name in the Deployment. */
const inLabNamespace = (yaml: string) => yaml.replace(/^( *)namespace: n8n$/gm, '$1namespace: lab-k8s').replaceAll('.n8n.svc.cluster.local', '.lab-k8s.svc.cluster.local');

/**
 * The shipped Postgres is sized for production: a 300 Gi claim, and requests of 1 CPU and 2 Gi. A one-node cloud
 * lab cannot fit that next to the cluster's own pods, so on a cloud the lab asks for 10 Gi, 100m and 512 Mi.
 */
const sized = (env: Env, yaml: string) =>
  env.provider.local
    ? yaml
    : yaml.replaceAll('storage: 300Gi', 'storage: 10Gi').replace(/requests:\n(\s+)cpu: "1"\n\s+memory: 2Gi/, 'requests:\n$1cpu: 100m\n$1memory: 512Mi');

/** The kubernetes/ manifests as shipped, with the namespace changed so the lab never touches a real install. */
function k8sSteps(env: Env): ListrTask[] {
  const dir = join(env.hosting, 'kubernetes');
  const ns = 'lab-k8s';
  return [
    step('Namespace and settings', async () => {
      await ensureNs(env, ns);
      await writeLabEnv(env, ns, 'k8s');
    }),
    step('Manifests', async (log) => {
      let deployment: string;
      try {
        deployment = readFileSync(join(dir, 'n8n-deployment.yaml'), 'utf8');
      } catch {
        throw new UserError(`No kubernetes/n8n-deployment.yaml under HOSTING=${env.hosting}`);
      }
      for (const f of readdirSync(dir).filter((f) => f.endsWith('.yaml') && f !== 'namespace.yaml' && f !== 'n8n-deployment.yaml')) {
        await apply(env, sized(env, inLabNamespace(readFileSync(join(dir, f), 'utf8'))), { onLine: log });
      }
      // The Deployment also gets the lab settings, and the local image when one is set.
      // A CPU limit alone makes Kubernetes request the same amount, so a small request is set too. Both are merged
      // into the manifest's own resources, so its memory settings stay.
      const container: Record<string, unknown> = { name: 'n8n', envFrom: [{ configMapRef: { name: 'lab-env' } }], resources: { requests: { cpu: '50m' }, limits: { cpu: '500m' } } };
      if (env.image || env.tag) container.image = `${env.image ?? 'n8nio/n8n'}:${env.tag ?? 'latest'}`;
      if (env.image && env.provider.local) container.imagePullPolicy = 'Never';
      const patched = await kubectl(env, ['patch', '--local', '-f', '-', '-o', 'yaml', '-p', JSON.stringify({ spec: { template: { spec: { containers: [container] } } } })], { input: inLabNamespace(deployment) });
      await apply(env, patched, { onLine: log });
    }),
    wait(env, ns),
  ];
}

/** A Compose stack from n8n-hosting, as shipped. A generated override (never your files) adds the lab settings. */
function composeSteps(env: Env, t: string): ListrTask[] {
  const { dir: rel, only, dataFolder } = COMPOSE[t];
  const dir = join(env.hosting, rel);
  const file = join(dir, 'docker-compose.yml');
  const data = composeData(t);
  // The shell wins over the stack's own .env, so this is how DATA_FOLDER resolves.
  const vars: Record<string, string> = dataFolder ? { DATA_FOLDER: data } : {};
  const dc = (args: string[], log?: Log) => compose(['-p', `lab-${t}`, '--project-directory', dir, '-f', file, ...args], { onLine: log, env: vars });
  return [
    ...(dataFolder
      ? [
          step('Data folder', async () => {
            // The subfolder stack's init container sets the owner of .n8n to user 1000. Caddy's stack mounts local_files.
            for (const d of ['.n8n', 'local_files', 'caddy_config']) mkdirSync(join(data, d), { recursive: true });
          }),
        ]
      : []),
    step('Override file', async () => {
      const services = (await dc(['config', '--services'])).split('\n');
      const image = env.image || env.tag ? JSON.stringify(`${env.image ?? 'docker.n8n.io/n8nio/n8n'}:${env.tag ?? 'latest'}`) : '';
      const lines = ['services:'];
      for (const svc of ['n8n', 'n8n-worker'].filter((s) => services.includes(s))) {
        lines.push(`  ${svc}:`);
        if (image) lines.push(`    image: ${image}`);
        if (env.image) lines.push('    pull_policy: never');
        if (svc === 'n8n') lines.push('    ports: !override []'); // frees the host port so stacks run side by side
        lines.push("    extra_hosts: ['host.docker.internal:host-gateway']", '    environment:');
        // JSON strings are valid YAML, so a value with a colon or a quote cannot break the file.
        for (const [k, v] of Object.entries(labEnv(env, t, true))) lines.push(`      - ${JSON.stringify(`${k}=${v}`)}`);
      }
      // The Caddy stack declares its volumes external, which must exist and are shared by every stack.
      // Making them ordinary volumes scopes them to this project, and `down -v` removes them.
      if (t === 'compose-caddy') lines.push('volumes:', '  caddy_data: !override {}', '  n8n_data: !override {}');
      mkdirSync(join(ROOT, '.compose'), { recursive: true });
      writeFileSync(join(ROOT, '.compose', `${t}.yml`), lines.join('\n') + '\n');
    }),
    step('Docker Compose up', (log) => dc(['-f', join(ROOT, '.compose', `${t}.yml`), 'up', '-d', ...(only ?? [])], log)),
  ];
}

/** Docker's own `compose` plugin when it exists, else the standalone docker-compose. Stacks need Compose 2.24 or later. */
let composeBin: Promise<[string, string[]]> | undefined;
const compose = (args: string[], opts: Parameters<typeof run>[2]) =>
  (composeBin ??= ok('docker', ['compose', 'version']).then((plugin): [string, string[]] => (plugin ? ['docker', ['compose']] : ['docker-compose', []]))).then(([bin, pre]) => run(bin, [...pre, ...args], opts));

const composeData = (t: string) => join(ROOT, '.compose', 'data', t);

export async function removeTargets(env: Env, targets: string[], log: Log) {
  for (const t of targets.filter(isCompose)) {
    await compose(['-p', `lab-${t}`, 'down', '-v'], { onLine: log, env: { DATA_FOLDER: composeData(t) } }).catch(() => {});
    rmSync(composeData(t), { recursive: true, force: true });
  }
  await removeNamespaces(env, targets.filter((t) => !isCompose(t)).map(namespaceOf), log);
}

/** Deletes namespaces and every trace of their data: leftover volumes, then the provider's disk folders. */
export async function removeNamespaces(env: Env, namespaces: string[], log: Log) {
  // Only namespaces the lab labelled are deleted, so a namespace of yours that happens to be called lab-* is safe.
  const mine = new Set(await labNamespaces(env, true));
  for (const ns of namespaces.filter((n) => !mine.has(n))) log(`Skipping ${ns}: it is not labelled as the lab's`);
  namespaces = namespaces.filter((n) => mine.has(n));
  if (!namespaces.length) return;
  await kubectl(env, ['delete', 'namespace', ...namespaces, '--ignore-not-found'], { onLine: log });
  const { items } = JSON.parse(await kubectl(env, ['get', 'pv', '-o', 'json']));
  const left: string[] = items.filter((pv: any) => namespaces.includes(pv.spec.claimRef?.namespace)).map((pv: any) => pv.metadata.name);
  if (left.length) await kubectl(env, ['delete', 'pv', ...left, '--ignore-not-found'], { onLine: log });
  await env.provider.wipeStorage?.(namespaces, env.ctx);
}

/** Targets that need an Enterprise licence key: multi-main, and any example that turns on multi-main or a licence. */
export const licensed = (env: Env, t: string) => t === 'multimain' || (isExample(t) && needsLicense(exampleValues(env, t)));

export const hasLicenseSecret = (env: Env, t: string) => exists(env, '-n', namespaceOf(t), 'secret', 'n8n-license');

/** Cluster targets that exist right now, read from the lab-* namespaces. */
export async function clusterTargets(env: Env): Promise<string[]> {
  return (await labNamespaces(env)).filter((n) => n.startsWith('lab-')).map((n) => n.slice('lab-'.length));
}
