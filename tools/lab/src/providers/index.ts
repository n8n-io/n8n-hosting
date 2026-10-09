import { has } from '../support/sh.ts';
import { UserError } from '../support/ui.ts';
import { aks } from './aks.ts';
import { eks } from './eks.ts';
import { minikube } from './minikube.ts';
import type { Provider } from './types.ts';

export type { Cluster, Provider } from './types.ts';

const PROVIDERS: Record<string, () => Provider> = { minikube: () => minikube, aws: eks, azure: aks };

export function getProvider(name: string): Provider {
  const make = Object.hasOwn(PROVIDERS, name) ? PROVIDERS[name] : undefined; // `constructor` is not a provider
  if (!make) throw new UserError(`Unknown provider '${name}'. Providers: ${Object.keys(PROVIDERS).join(', ')}`);
  return make();
}

const INSTALL: Record<string, string> = {
  minikube: 'https://minikube.sigs.k8s.io/docs/start/ (macOS: brew install minikube)',
  docker: 'https://docs.docker.com/get-started/get-docker/ (macOS: Docker Desktop or Colima)',
  eksctl: 'https://eksctl.io/installation/ (macOS: brew install eksctl)',
  aws: 'https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html',
  az: 'https://learn.microsoft.com/cli/azure/install-azure-cli',
  kubectl: 'https://kubernetes.io/docs/tasks/tools/',
  helm: 'https://helm.sh/docs/intro/install/',
};

/** Stops before anything is created when a CLI the provider drives is missing, and says how to install it. */
export async function requireClis(provider: Provider): Promise<void> {
  const missing: string[] = [];
  for (const bin of [...provider.clis, 'kubectl', 'helm']) if (!(await has(bin))) missing.push(bin);
  if (!missing.length) return;
  const hints = missing.map((bin) => `  ${bin}: ${INSTALL[bin] ?? 'see its docs'}`).join('\n');
  throw new UserError(`The ${provider.name} provider needs ${missing.join(', ')}, which ${missing.length > 1 ? 'are' : 'is'} not installed.\n${hints}`);
}
