import { run } from '../support/sh.ts';
import { UserError } from '../support/ui.ts';
import type { Provider } from './types.ts';

interface MinikubeProfile {
  Name: string;
  Status: string;
  Config?: { CPUs?: number; Memory?: number };
}

const GIB = 1024 ** 3;

export const minikube: Provider = {
  name: 'minikube',
  local: true,
  shared: true, // every minikube profile is listed, including your own
  clis: ['minikube', 'docker'],
  defaultName: () => 'minikube',
  async list() {
    const out = JSON.parse(await run('minikube', ['profile', 'list', '-o', 'json']).catch(() => '{}')) as { valid?: MinikubeProfile[] };
    return (out.valid ?? []).map((p) => ({
      name: p.Name,
      // The profile list reports health ("OK") for a running cluster and "Stopped" or "Paused" otherwise.
      running: !/stopped|paused/i.test(p.Status),
      detail: p.Config?.CPUs && p.Config.Memory ? `${p.Config.CPUs} CPUs, ${Math.round(p.Config.Memory / 1024)} GB` : '',
    }));
  },
  async create(name, log) {
    await run('minikube', ['start', '-p', name, '--cpus', '6', '--memory', '12g'], { onLine: log });
  },
  async connect(name) {
    // The whole lab uses about 6 GiB. Below 8 the node swaps and the API server stops answering.
    const memory = Number(await run('docker', ['inspect', name, '--format', '{{.HostConfig.Memory}}']).catch(() => '0'));
    if (memory > 0 && memory < 8 * GIB) {
      throw new UserError(`${name} has ${Math.floor(memory / GIB)} GiB. Raise it first:\n  docker update --memory 12g --memory-swap 12g ${name}`);
    }
    return name;
  },
  async destroy(name, log) {
    await run('minikube', ['delete', '-p', name], { onLine: log });
  },
  // minikube's provisioner marks a deleted claim's volume Released but never removes its folder, so the next
  // install in the same namespace finds the old data. The kube context of a minikube cluster is its profile name.
  async wipeStorage(namespaces, ctx) {
    const dirs = namespaces.filter((n) => /^lab-[a-z0-9-]+$/.test(n)).map((n) => `/tmp/hostpath-provisioner/${n}`);
    if (dirs.length) await run('minikube', ['ssh', '-p', ctx, '--', `sudo rm -rf ${dirs.join(' ')}`]);
  },
};
