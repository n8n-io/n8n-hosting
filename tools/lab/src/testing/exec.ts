import { type Env, exists, kubectl } from '../cluster/kube.ts';
import { run } from '../support/sh.ts';
import { composeProject, isCompose, mainDeployment, namespaceOf } from '../targets/index.ts';

/** Runs a shell command inside n8n's container and returns what it printed. */
export type Exec = (command: string) => Promise<string>;

export interface Reach {
  /** The main instance. */
  main: Exec;
  /** Where production webhooks are served: a webhook processor when there is one, else main. */
  webhook: Exec;
}

/** How to run a command inside a target's n8n, so no port ever has to be published. */
export function execFor(env: Env, t: string): Reach {
  if (isCompose(t)) {
    const exec: Exec = (cmd) => run('docker', ['exec', `${composeProject(t)}-n8n-1`, 'sh', '-c', cmd]);
    return { main: exec, webhook: exec };
  }
  const ns = namespaceOf(t);
  const inDeploy = (name: string): Exec => (cmd) => kubectl(env, ['-n', ns, 'exec', '--pod-running-timeout=10s', `deploy/${name}`, '--', 'sh', '-c', cmd]);
  const main = inDeploy(mainDeployment(t));
  const processor = inDeploy('n8n-webhook-processor');
  const webhook: Exec = async (cmd) => ((await exists(env, '-n', ns, 'deploy', 'n8n-webhook-processor')) ? processor(cmd) : main(cmd));
  return { main, webhook };
}

/** A GET against n8n from inside its own container. wget prints the status line, which is where the status comes from. */
export async function httpGet(exec: Exec, path: string): Promise<{ status: number; body: string }> {
  const out = await exec(`wget -S -qO- http://localhost:5678${path} 2>&1; true`);
  return { status: statusOf(out), body: out };
}

/** The status code in wget's output, or 0 when there was no response. */
export const statusOf = (wgetOutput: string): number => Number(/HTTP\/1\.\d (\d{3})/.exec(wgetOutput)?.[1] ?? 0);
