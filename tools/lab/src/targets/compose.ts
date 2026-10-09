import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import type { ListrTask } from 'listr2';
import { type Env, ROOT } from '../cluster/kube.ts';
import { labEnv } from '../cluster/settings.ts';
import { ok, run } from '../support/sh.ts';
import { COMPOSE } from './names.ts';
import { type Log, step } from './steps.ts';

type RunOpts = Parameters<typeof run>[2];

/** Docker's own `compose` plugin when it exists, else the standalone docker-compose. Stacks need Compose 2.24 or later. */
let composeBin: Promise<[string, string[]]> | undefined;
const compose = (args: string[], opts: RunOpts) => {
  composeBin ??= ok('docker', ['compose', 'version']).then((plugin): [string, string[]] => (plugin ? ['docker', ['compose']] : ['docker-compose', []]));
  return composeBin.then(([bin, prefix]) => run(bin, [...prefix, ...args], opts));
};

const projectOf = (t: string) => `lab-${t}`;
const dataFolder = (t: string) => join(ROOT, '.compose', 'data', t);
const overrideFile = (t: string) => join(ROOT, '.compose', `${t}.yml`);

interface OverrideInput {
  /** The services the stack defines. Only n8n and its worker get the lab's changes. */
  services: string[];
  /** The image to run, when it is not the one the stack ships. */
  image?: string;
  /** The image only exists on this machine, so never pull it. */
  neverPull: boolean;
  /** n8n settings, from labEnv. */
  settings: Record<string, string>;
  /** The Caddy stack declares its volumes external, so they have to be made ordinary and project-scoped. */
  ownVolumes: boolean;
}

/** The override file the lab lays over a shipped stack. The stack's own files are never edited. */
export function composeOverride({ services, image, neverPull, settings, ownVolumes }: OverrideInput): string {
  const lines = ['services:'];
  for (const svc of ['n8n', 'n8n-worker'].filter((s) => services.includes(s))) {
    lines.push(`  ${svc}:`);
    if (image) lines.push(`    image: ${JSON.stringify(image)}`);
    if (neverPull) lines.push('    pull_policy: never');
    if (svc === 'n8n') lines.push('    ports: !override []'); // frees the host port so stacks run side by side
    lines.push("    extra_hosts: ['host.docker.internal:host-gateway']", '    environment:');
    // JSON strings are valid YAML, so a value with a colon or a quote cannot break the file.
    for (const [k, v] of Object.entries(settings)) lines.push(`      - ${JSON.stringify(`${k}=${v}`)}`);
  }
  // Ordinary volumes are scoped to this project, so `down -v` removes them and real ones are never touched.
  if (ownVolumes) lines.push('volumes:', '  caddy_data: !override {}', '  n8n_data: !override {}');
  return lines.join('\n') + '\n';
}

/** A Compose stack from n8n-hosting, as shipped. A generated override (never your files) adds the lab settings. */
export function composeSteps(env: Env, t: string): ListrTask[] {
  const stack = COMPOSE[t];
  const dir = join(env.hosting, stack.dir);
  // The shell wins over the stack's own .env, so this is how DATA_FOLDER resolves.
  const vars: Record<string, string> = stack.dataFolder ? { DATA_FOLDER: dataFolder(t) } : {};
  const dc = (args: string[], log?: Log) => compose(['-p', projectOf(t), '--project-directory', dir, '-f', join(dir, 'docker-compose.yml'), ...args], { onLine: log, env: vars });
  const image = env.image || env.tag ? `${env.image ?? 'docker.n8n.io/n8nio/n8n'}:${env.tag ?? 'latest'}` : undefined;
  return [
    ...(stack.dataFolder
      ? [
          step('Data folder', async () => {
            // The subfolder stack's init container sets the owner of .n8n to user 1000. Caddy's stack mounts local_files.
            for (const d of ['.n8n', 'local_files', 'caddy_config']) mkdirSync(join(dataFolder(t), d), { recursive: true });
          }),
        ]
      : []),
    step('Override file', async () => {
      const services = (await dc(['config', '--services'])).split('\n');
      mkdirSync(join(ROOT, '.compose'), { recursive: true });
      writeFileSync(overrideFile(t), composeOverride({ services, image, neverPull: !!env.image, settings: labEnv(env, t, true), ownVolumes: t === 'compose-caddy' }));
    }),
    step('Docker Compose up', (log) => dc(['-f', overrideFile(t), 'up', '-d', ...(stack.only ?? [])], log)),
  ];
}

/** Stops a stack, removes its volumes, and deletes the data folder the lab made for it. */
export async function removeCompose(t: string, log: Log): Promise<void> {
  await compose(['-p', projectOf(t), 'down', '-v'], { onLine: log, env: { DATA_FOLDER: dataFolder(t) } }).catch(() => {});
  rmSync(dataFolder(t), { recursive: true, force: true });
}

/** The compose project name of a target, which is what its containers are labelled with. */
export const composeProject = projectOf;

/** A stack's containers, running or not. Empty when the stack is not deployed. */
export async function composeContainers(t: string): Promise<{ name: string; status: string }[]> {
  const out = await run('docker', ['ps', '-a', '--filter', `label=com.docker.compose.project=${projectOf(t)}`, '--format', '{{.Names}}\t{{.Status}}']);
  return out.trim().split('\n').filter(Boolean).map((line) => {
    const [name, status] = line.split('\t');
    return { name, status };
  });
}
