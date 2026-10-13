import type { Addon } from '../src/addons.ts';
import type { Env } from '../src/cluster/kube.ts';
import type { Provider } from '../src/providers/types.ts';

const provider = (local: boolean): Provider => ({ name: local ? 'minikube' : 'aws', local, clis: [], defaultName: () => 'x', list: async () => [], create: async () => {}, connect: async () => 'ctx', destroy: async () => {} });

/** An Env for tests that never touches a cluster. */
export const fakeEnv = (over: Partial<Env> & { local?: boolean; addons?: Addon[] } = {}): Env => ({
  provider: provider(over.local ?? true),
  cluster: 'test',
  ctx: 'test',
  addons: [],
  extraEnv: {},
  valuesFiles: [],
  hosting: '/nowhere',
  chart: '/nowhere/charts/n8n',
  ...over,
});
