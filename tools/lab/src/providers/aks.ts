import { ok, run } from '../support/sh.ts';
import { UserError } from '../support/ui.ts';
import { LAB_TAG, LAB_TAGS, OLD_LAB_TAG, isLabTag, labName, owner, runningFor } from './lab.ts';
import type { Provider } from './types.ts';

const HOURLY = 'The AKS control plane is free, and the node costs about $0.08 an hour.';

/** Each cluster gets its own resource group, so deleting the group removes everything the cluster made. */
export const resourceGroup = (cluster: string) => `${cluster}-rg`;

/** The registry name is global in Azure, so it carries the owner and the start of the subscription id. */
export const registryName = (who: string, subscriptionId: string) => `lab${who.replace(/-/g, '')}${subscriptionId.slice(0, 6)}`.slice(0, 50);

export function aks(): Provider {
  // The smallest setup that runs the lab: one node with 2 vCPUs and 8 GB. Raise it for many targets at once.
  const size = process.env.LAB_AZURE_NODE_SIZE || 'Standard_B2ms';
  const nodes = Number(process.env.LAB_AZURE_NODES || 1);

  // AZURE_LOCATION wins, then the default in the Azure CLI config.
  async function location(): Promise<string> {
    const found = process.env.AZURE_LOCATION || (await run('az', ['config', 'get', 'defaults.location', '--query', 'value', '-o', 'tsv']).catch(() => '')).trim();
    if (!found) throw new UserError('Set AZURE_LOCATION, for example: AZURE_LOCATION=westeurope');
    return found;
  }

  async function account(): Promise<{ id: string; name: string; user: { name: string } }> {
    try {
      return JSON.parse(await run('az', ['account', 'show', '-o', 'json']));
    } catch {
      throw new UserError('You are not logged in to Azure. Run `az login`, then try again.');
    }
  }

  const registry = async () => registryName(owner, (await account()).id);

  /** A group left by an earlier failed attempt can sit in another location and block a new cluster. */
  async function clearDebrisGroup(group: string, log: (line: string) => void): Promise<void> {
    if ((await run('az', ['group', 'exists', '-n', group])).trim() !== 'true') return;
    const empty = (await run('az', ['resource', 'list', '-g', group, '--query', 'length(@)', '-o', 'tsv'])).trim() === '0';
    const ours = isLabTag((await run('az', ['group', 'show', '-n', group, '--query', 'tags.lab', '-o', 'tsv'])).trim());
    // If it is the lab's own and empty it is debris, so it is replaced. Anything else is left alone.
    if (!empty || !ours) throw new UserError(`Resource group ${group} already exists and is not an empty lab group. Pick another name with --cluster.`);
    await run('az', ['group', 'delete', '-n', group, '--yes'], { onLine: log });
  }

  return {
    name: 'azure',
    local: false,
    clis: ['az'],
    defaultName: () => `lab-${owner}`,
    // Only clusters tagged by the lab, with a lab- name, are listed or deleted, so it never touches anyone else's.
    normalize: labName,
    async plan(name) {
      const who = await account();
      return `AKS cluster ${name} in ${await location()}: ${nodes} x ${size}.\nSubscription: ${who.name} (${who.user.name}).\n${HOURLY} Takes about 5 minutes.`;
    },
    async info(name) {
      const created = (await run('az', ['aks', 'show', '-g', resourceGroup(name), '-n', name, '--query', 'tags.created', '-o', 'tsv']).catch(() => '')).trim();
      return `${runningFor(created)}. ${HOURLY} Delete it when you are done: ./lab cluster delete ${name}`;
    },
    async list() {
      await account();
      const query = `[?tags.lab=='${LAB_TAG}' || tags.lab=='${OLD_LAB_TAG}'].{name:name,location:location,state:powerState.code}`;
      const out = await run('az', ['aks', 'list', '--query', query, '-o', 'json']);
      return (JSON.parse(out) as { name: string; location: string; state: string }[])
        .filter((c) => c.name.startsWith('lab-'))
        .map((c) => ({ name: c.name, running: c.state === 'Running', detail: c.location }));
    },
    async create(name, log) {
      const where = await location();
      const tags = [...LAB_TAGS, `created=${new Date().toISOString()}`];
      const group = resourceGroup(name);
      await clearDebrisGroup(group, log);
      await run('az', ['group', 'create', '-n', group, '-l', where, '--tags', ...tags], { onLine: log });
      log('Creating the cluster (about 5 minutes)');
      try {
        await run('az', ['aks', 'create', '-g', group, '-n', name, '-l', where, '--node-count', String(nodes), '--node-vm-size', size, '--no-ssh-key', '--tags', ...tags], { onLine: log });
      } catch (e) {
        // Do not leave an empty resource group behind.
        await run('az', ['group', 'delete', '-n', group, '--yes', '--no-wait']).catch(() => {});
        throw e;
      }
    },
    async connect(name) {
      const ctx = `azure-${name}`;
      await run('az', ['aks', 'get-credentials', '-g', resourceGroup(name), '-n', name, '--context', ctx, '--overwrite-existing']);
      return ctx;
    },
    // The registry lives in the cluster's resource group, so `cluster delete` removes it too.
    registry: {
      async ensure(cluster, log) {
        const acr = await registry();
        const group = resourceGroup(cluster);
        // A new subscription has not enabled the registry service yet. Free, and a one-time step.
        if ((await run('az', ['provider', 'show', '-n', 'Microsoft.ContainerRegistry', '--query', 'registrationState', '-o', 'tsv']).catch(() => '')).trim() !== 'Registered') {
          await run('az', ['provider', 'register', '-n', 'Microsoft.ContainerRegistry', '--wait'], { onLine: log });
        }
        if (!(await ok('az', ['acr', 'show', '-n', acr]))) {
          await run('az', ['acr', 'create', '-g', group, '-n', acr, '--sku', 'Basic', '--tags', ...LAB_TAGS], { onLine: log });
        }
        await run('az', ['aks', 'update', '-g', group, '-n', cluster, '--attach-acr', acr], { onLine: log });
        await run('az', ['acr', 'login', '-n', acr]);
        return `${acr}.azurecr.io/n8n`;
      },
      async remove(_cluster, log) {
        await run('az', ['acr', 'delete', '-n', await registry(), '--yes'], { onLine: log });
      },
    },
    async destroy(name, log) {
      await run('az', ['group', 'delete', '-n', resourceGroup(name), '--yes'], { onLine: log });
    },
  };
}
