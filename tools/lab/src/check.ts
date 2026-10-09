import type { ListrTask } from 'listr2';
import { type Env, exists, kubectl } from './kube.ts';
import { COMPOSE_TARGETS, clusterTargets, isCompose, namespaceOf } from './targets.ts';
import { run } from './sh.ts';

type Exec = (command: string) => Promise<string>;

/** A GET against n8n from inside its own container, so no port has to be published. */
export async function get(exec: Exec, path: string) {
  const out = await exec(`wget -S -qO- http://localhost:5678${path} 2>&1; true`);
  return { status: Number(/HTTP\/1\.\d (\d{3})/.exec(out)?.[1] ?? 0), body: out };
}

const expectStatus = async (exec: Exec, path: string, want: number, contains?: string) => {
  const { status, body } = await get(exec, path);
  if (status !== want) throw new Error(`GET ${path} returned ${status || 'no response'}, expected ${want}`);
  if (contains && !body.includes(contains)) throw new Error(`GET ${path} did not contain "${contains}"`);
};

/** Subtask failures do not reach the top-level run when exitOnError is off, so they are counted here. */
export const failed: string[] = [];

export const check = (title: string, fn: () => Promise<unknown>): ListrTask => ({
  title,
  task: async () => {
    try {
      // n8n can take a few seconds to serve after its pod is ready, so a check retries before it fails.
      for (let attempt = 1; ; attempt++) {
        try {
          return void (await fn());
        } catch (e) {
          if (attempt === 10) throw e;
          await new Promise((r) => setTimeout(r, 2000));
        }
      }
    } catch (e) {
      failed.push(title);
      throw e;
    }
  },
});

/** Containers or deployments that serve n8n for a target, and how to run a command in one. */
export function execFor(env: Env, t: string): { main: Exec; webhook: Exec } {
  if (isCompose(t)) {
    const exec: Exec = (cmd) => run('docker', ['exec', `lab-${t}-n8n-1`, 'sh', '-c', cmd]);
    return { main: exec, webhook: exec };
  }
  const ns = namespaceOf(t);
  const inDeploy = (name: string): Exec => (cmd) => kubectl(env, ['-n', ns, 'exec', '--pod-running-timeout=10s', `deploy/${name}`, '--', 'sh', '-c', cmd]);
  const main = inDeploy(t === 'k8s' ? 'n8n' : 'n8n-main');
  // With webhook processors, production webhooks are served by them, not by main.
  const processor = inDeploy('n8n-webhook-processor');
  const webhook: Exec = async (cmd) => ((await exists(env, '-n', ns, 'deploy', 'n8n-webhook-processor')) ? processor(cmd) : main(cmd));
  return { main, webhook };
}

export const checkTask = (env: Env, t: string): ListrTask => ({
  title: t,
  task: (_, task) => {
    const { main, webhook } = execFor(env, t);
    // The subfolder stack serves everything under a path prefix, so only health is checked there.
    const prefixed = t === 'compose-subfolder-with-ssl';
    task.title = t;
    return task.newListr(
      [
        ...(isCompose(t) ? [] : [check('Pods ready', () => kubectl(env, ['-n', namespaceOf(t), 'wait', '--for=condition=Available', 'deploy', '--all', '--timeout=30s']))]),
        check('Health', () => expectStatus(main, '/healthz', 200)),
        check('Readiness (database reachable)', () => expectStatus(main, '/healthz/readiness', 200)),
        ...(prefixed ? [] : [check('Editor loads', () => expectStatus(main, '/', 200, 'n8n')), check('Webhook route answers', () => expectStatus(webhook, '/webhook/lab-check', 404))]),
      ],
      { concurrent: false, exitOnError: false },
    );
  },
});

/** Targets that are deployed right now. */
export async function deployedTargets(env: Env): Promise<string[]> {
  const found: string[] = [];
  found.push(...(await clusterTargets(env)));
  for (const t of COMPOSE_TARGETS) {
    if ((await run('docker', ['ps', '-q', '--filter', `label=com.docker.compose.project=lab-${t}`])).trim()) found.push(t);
  }
  return found;
}

