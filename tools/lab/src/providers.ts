import { userInfo } from 'node:os';
import { has, ok, run } from './sh.ts';
import { UserError } from './ui.ts';

export interface Cluster {
  name: string;
  running: boolean;
  /** A few words about it, shown in the cluster list. */
  detail?: string;
}

type Log = (line: string) => void;

/**
 * A place to run the lab. It manages named clusters and hands back a kube context; everything else is shared.
 * A cluster outlives its deployments: `down` removes deployments, only `cluster delete` removes a cluster.
 */
export interface Provider {
  name: string;
  /** Local providers can use images loaded into the cluster and run Compose targets. */
  local: boolean;
  /** True when the cluster list may hold clusters the lab did not create, so deleting one needs extra care. */
  shared?: boolean;
  /** CLIs this provider drives. A missing one stops the run before anything is created. */
  clis: string[];
  /** The name offered when you create a new cluster. */
  defaultName(): string;
  /** Turns a name you typed into the one the provider uses, so the lab can find its own clusters again. */
  normalize?(name: string): string;
  /** What creating a cluster will cost and take, shown before the user is asked to confirm. */
  plan?(name: string): Promise<string>;
  /** What a running cluster is costing, shown by `status` so an idle one is not forgotten. */
  info?(name: string): Promise<string>;
  list(): Promise<Cluster[]>;
  /** Creates the cluster, or starts it if it exists but is stopped. */
  create(name: string, log: Log): Promise<void>;
  /** Returns the kube context for the cluster. */
  connect(name: string): Promise<string>;
  destroy(name: string, log: Log): Promise<void>;
  /** A registry the cluster can pull from. Optional: a local provider uses images loaded into the cluster. */
  registry?: {
    /** Creates the registry if needed, lets the cluster pull from it and logs Docker in. Returns the repository to push to. */
    ensure(cluster: string, log: Log): Promise<string>;
    remove(cluster: string, log: Log): Promise<void>;
  };
  /** Removes storage a deleted namespace left behind. Optional: a cloud cluster takes its disks with it. */
  wipeStorage?(namespaces: string[], ctx: string): Promise<void>;
}

const INSTALL: Record<string, string> = {
  minikube: 'brew install minikube',
  docker: 'install Docker Desktop or Colima',
  eksctl: 'brew install eksctl',
  aws: 'brew install awscli',
  az: 'brew install azure-cli',
};

export async function requireClis(p: Provider): Promise<void> {
  const missing: string[] = [];
  for (const bin of [...p.clis, 'kubectl', 'helm']) if (!(await has(bin))) missing.push(bin);
  if (missing.length) {
    const hints = missing.map((b) => `  ${b}: ${INSTALL[b] ?? 'see its docs'}`).join('\n');
    throw new UserError(`The ${p.name} provider needs ${missing.join(', ')}, which ${missing.length > 1 ? 'are' : 'is'} not installed.\n${hints}`);
  }
}

const minikube: Provider = {
  name: 'minikube',
  local: true,
  shared: true, // every minikube profile is listed, including your own
  clis: ['minikube', 'docker'],
  defaultName: () => 'minikube',
  async list() {
    const out = JSON.parse(await run('minikube', ['profile', 'list', '-o', 'json']).catch(() => '{}'));
    return (out.valid ?? []).map((p: any) => ({
      name: p.Name,
      // The profile list reports health ("OK") for a running cluster and "Stopped" or "Paused" otherwise.
      running: !/stopped|paused/i.test(p.Status),
      detail: p.Config?.CPUs ? `${p.Config.CPUs} CPUs, ${Math.round(p.Config.Memory / 1024)} GB` : '',
    }));
  },
  async create(name, log) {
    await run('minikube', ['start', '-p', name, '--cpus', '6', '--memory', '12g'], { onLine: log });
  },
  async connect(name) {
    // The whole lab uses about 6 GiB. Below 8 the node swaps and the API server stops answering.
    const mem = Number(await run('docker', ['inspect', name, '--format', '{{.HostConfig.Memory}}']).catch(() => '0'));
    if (mem > 0 && mem < 8 * 1024 ** 3) {
      throw new UserError(`${name} has ${Math.floor(mem / 1024 ** 3)} GiB. Raise it first:\n  docker update --memory 12g --memory-swap 12g ${name}`);
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

/** eksctl's lines are written for its own log. This turns the milestones into what a person is waiting for. */
export function friendly(line: string): string {
  const text = line.replace(/^\S+ \S+ \[\S+\]\s+/, '');
  if (/building cluster stack|creating cluster stack|waiting for CloudFormation stack "eksctl-.*-cluster"/i.test(text)) return 'Creating the control plane (about 10 minutes)';
  if (/nodegroup/i.test(text)) return 'Creating the node group (about 5 minutes)';
  if (/addon/i.test(text)) return 'Installing the storage addon';
  if (/saved kubeconfig|is ready/i.test(text)) return 'Cluster is ready';
  return text;
}

// Tag on everything the lab creates. Clusters made before the rename carry the old value, so both are accepted.
const LAB_TAG = 'n8n-hosting-lab';
const OLD_LAB_TAG = 'n8n-deployment-lab';
const isLabTag = (v: string) => v === LAB_TAG || v === OLD_LAB_TAG;

const owner = userInfo().username.toLowerCase().replace(/[^a-z0-9-]/g, '-');

function eks(): Provider {
  // The smallest setup that runs the lab: one node. Raise it for many targets at once.
  const nodeType = process.env.LAB_AWS_NODE_TYPE || 't3.large';
  const nodes = Number(process.env.LAB_AWS_NODES || 1);
  // AWS_REGION wins, then the region in the AWS CLI config.
  const getRegion = async () => {
    const region = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || (await run('aws', ['configure', 'get', 'region']).catch(() => '')).trim();
    if (!region) throw new UserError('Set AWS_REGION, for example: AWS_REGION=eu-west-1');
    return region;
  };
  const regionArgs = async () => ['--region', await getRegion()];
  const credentials = async () => {
    if (!(await ok('aws', ['sts', 'get-caller-identity']))) throw new UserError('AWS credentials are not valid. Run `aws sso login` or `aws configure`, then try again.');
  };
  const hourly = 'The control plane costs about $0.10 an hour, and each t3.large node about $0.09.';
  return {
    name: 'aws',
    local: false,
    clis: ['aws', 'eksctl'],
    defaultName: () => `lab-${owner}`,
    // Only clusters whose name starts with lab- are the lab's, so it never lists or deletes anyone else's.
    normalize: (name) => (name.startsWith('lab-') ? name : `lab-${name}`),
    async plan(name) {
      return `EKS cluster ${name} in ${await getRegion()}: ${nodes} x ${nodeType}, 20 GB disk each.\n${hourly} Takes about 15 minutes.`;
    },
    async info(name) {
      const created = (await run('aws', ['eks', 'describe-cluster', '--name', name, ...(await regionArgs()), '--query', 'cluster.createdAt', '--output', 'text']).catch(() => '')).trim();
      const minutes = created ? Math.floor((Date.now() - new Date(created).getTime()) / 60000) : 0;
      return `running for ${Math.floor(minutes / 60)}h ${minutes % 60}m. ${hourly} Delete it when you are done: ./lab cluster delete ${name}`;
    },
    async list() {
      await credentials();
      const out = await run('eksctl', ['get', 'cluster', ...(await regionArgs()), '-o', 'json']).catch(() => '[]');
      // The name prefix is not enough: a cluster is the lab's only when it also carries the lab tag.
      const named = (JSON.parse(out) as { Name: string; Region?: string }[]).filter((c) => c.Name.startsWith('lab-'));
      const region = await getRegion();
      const tagged = await Promise.all(named.map(async (c) => isLabTag((await run('aws', ['eks', 'describe-cluster', '--name', c.Name, '--region', region, '--query', 'cluster.tags.lab', '--output', 'text']).catch(() => '')).trim())));
      return named.filter((_, i) => tagged[i]).map((c) => ({ name: c.Name, running: true, detail: c.Region ?? '' }));
    },
    async create(name, log) {
      const region = await getRegion();
      const config = {
        apiVersion: 'eksctl.io/v1alpha5',
        kind: 'ClusterConfig',
        metadata: { name, region, tags: { lab: LAB_TAG, owner } },
        iam: { withOIDC: true },
        managedNodeGroups: [{ name: 'lab', instanceType: nodeType, desiredCapacity: nodes, minSize: nodes, maxSize: nodes, volumeSize: 20 }],
        addons: [{ name: 'aws-ebs-csi-driver', wellKnownPolicies: { ebsCSIController: true } }],
      };
      await run('eksctl', ['create', 'cluster', '-f', '-'], { input: JSON.stringify(config), onLine: (line) => log(friendly(line)) });
    },
    async connect(name) {
      // The provider is in the context name, so two providers' clusters with the same name never collide.
      const ctx = `aws-${name}`;
      await run('aws', ['eks', 'update-kubeconfig', '--name', name, ...(await regionArgs()), '--alias', ctx]);
      return ctx;
    },
    // One ECR repository per region. Managed node groups get read access to ECR in the same account.
    registry: {
      async ensure(_cluster, log) {
        const region = await getRegion();
        const repo = 'lab-n8n';
        const found = await run('aws', ['ecr', 'describe-repositories', '--repository-names', repo, '--region', region, '--query', 'repositories[0].repositoryUri', '--output', 'text']).catch(() => '');
        const uri = found.trim() || (await run('aws', ['ecr', 'create-repository', '--repository-name', repo, '--region', region, '--tags', `Key=lab,Value=${LAB_TAG}`, `Key=owner,Value=${owner}`, '--query', 'repository.repositoryUri', '--output', 'text'], { onLine: log })).trim();
        const password = (await run('aws', ['ecr', 'get-login-password', '--region', region])).trim();
        await run('docker', ['login', '--username', 'AWS', '--password-stdin', uri.split('/')[0]], { input: password });
        return uri;
      },
      async remove(_cluster, log) {
        const region = await getRegion();
        const arn = (await run('aws', ['ecr', 'describe-repositories', '--repository-names', 'lab-n8n', '--region', region, '--query', 'repositories[0].repositoryArn', '--output', 'text']).catch(() => '')).trim();
        const tag = arn && (await run('aws', ['ecr', 'list-tags-for-resource', '--resource-arn', arn, '--region', region, '--query', "tags[?Key=='lab'].Value | [0]", '--output', 'text']).catch(() => '')).trim();
        if (!arn || !isLabTag(tag)) throw new UserError('The lab-n8n repository is not tagged as the lab\'s, so it is left alone.');
        await run('aws', ['ecr', 'delete-repository', '--repository-name', 'lab-n8n', '--force', ...(await regionArgs())], { onLine: log });
      },
    },
    async destroy(name, log) {
      await run('eksctl', ['delete', 'cluster', '--name', name, ...(await regionArgs()), '--wait'], { onLine: log });
    },
  };
}

const LAB_TAGS = [`lab=${LAB_TAG}`, `owner=${owner}`];

function aks(): Provider {
  // The smallest setup that runs the lab: one node with 2 vCPUs and 8 GB. Raise it for many targets at once.
  const size = process.env.LAB_AZURE_NODE_SIZE || 'Standard_B2ms';
  const nodes = Number(process.env.LAB_AZURE_NODES || 1);
  // AZURE_LOCATION wins, then the default in the Azure CLI config.
  const getLocation = async () => {
    const location = process.env.AZURE_LOCATION || (await run('az', ['config', 'get', 'defaults.location', '--query', 'value', '-o', 'tsv']).catch(() => '')).trim();
    if (!location) throw new UserError('Set AZURE_LOCATION, for example: AZURE_LOCATION=westeurope');
    return location;
  };
  const account = async () => {
    try {
      return JSON.parse(await run('az', ['account', 'show', '-o', 'json'])) as { name: string; user: { name: string } };
    } catch {
      throw new UserError('You are not logged in to Azure. Run `az login`, then try again.');
    }
  };
  // Each cluster gets its own resource group, so deleting the group removes everything the cluster made.
  const group = (name: string) => `${name}-rg`;
  const hourly = 'The AKS control plane is free, and the node costs about $0.08 an hour.';
  return {
    name: 'azure',
    local: false,
    clis: ['az'],
    defaultName: () => `lab-${owner}`,
    // Only clusters tagged by the lab, with a lab- name, are listed or deleted, so it never touches anyone else's.
    normalize: (name) => (name.startsWith('lab-') ? name : `lab-${name}`),
    async plan(name) {
      const a = await account();
      return `AKS cluster ${name} in ${await getLocation()}: ${nodes} x ${size}.\nSubscription: ${a.name} (${a.user.name}).\n${hourly} Takes about 5 minutes.`;
    },
    async info(name) {
      const created = (await run('az', ['aks', 'show', '-g', group(name), '-n', name, '--query', 'tags.created', '-o', 'tsv']).catch(() => '')).trim();
      const minutes = created ? Math.floor((Date.now() - new Date(created).getTime()) / 60000) : 0;
      return `running for ${Math.floor(minutes / 60)}h ${minutes % 60}m. ${hourly} Delete it when you are done: ./lab cluster delete ${name}`;
    },
    async list() {
      await account();
      const out = await run('az', ['aks', 'list', '--query', `[?tags.lab=='${LAB_TAG}' || tags.lab=='${OLD_LAB_TAG}'].{name:name,location:location,state:powerState.code}`, '-o', 'json']);
      return (JSON.parse(out) as { name: string; location: string; state: string }[])
        .filter((c) => c.name.startsWith('lab-'))
        .map((c) => ({ name: c.name, running: c.state === 'Running', detail: c.location }));
    },
    async create(name, log) {
      const location = await getLocation();
      const tags = [...LAB_TAGS, `created=${new Date().toISOString()}`];
      const g = group(name);
      // A group left by an earlier failed attempt can sit in another location and block this one. If it is the
      // lab's own and empty it is debris, so it is replaced. Anything else is left alone.
      if ((await run('az', ['group', 'exists', '-n', g])).trim() === 'true') {
        const empty = (await run('az', ['resource', 'list', '-g', g, '--query', 'length(@)', '-o', 'tsv'])).trim() === '0';
        const ours = isLabTag((await run('az', ['group', 'show', '-n', g, '--query', 'tags.lab', '-o', 'tsv'])).trim());
        if (!empty || !ours) throw new UserError(`Resource group ${g} already exists and is not an empty lab group. Pick another name with --cluster.`);
        await run('az', ['group', 'delete', '-n', g, '--yes'], { onLine: log });
      }
      await run('az', ['group', 'create', '-n', g, '-l', location, '--tags', ...tags], { onLine: log });
      log('Creating the cluster (about 5 minutes)');
      try {
        await run('az', ['aks', 'create', '-g', g, '-n', name, '-l', location, '--node-count', String(nodes), '--node-vm-size', size, '--no-ssh-key', '--tags', ...tags], { onLine: log });
      } catch (e) {
        // Do not leave an empty resource group behind.
        await run('az', ['group', 'delete', '-n', g, '--yes', '--no-wait']).catch(() => {});
        throw e;
      }
    },
    async connect(name) {
      const ctx = `azure-${name}`;
      await run('az', ['aks', 'get-credentials', '-g', group(name), '-n', name, '--context', ctx, '--overwrite-existing']);
      return ctx;
    },
    // The registry lives in the cluster's resource group, so `cluster delete` removes it too.
    registry: {
      async ensure(cluster, log) {
        const sub = (await account()) && (await run('az', ['account', 'show', '--query', 'id', '-o', 'tsv'])).trim().slice(0, 6);
        const acr = `lab${owner.replace(/-/g, '')}${sub}`.slice(0, 50);
        const g = group(cluster);
        // A new subscription has not enabled the registry service yet. Free, and a one-time step.
        if ((await run('az', ['provider', 'show', '-n', 'Microsoft.ContainerRegistry', '--query', 'registrationState', '-o', 'tsv']).catch(() => '')).trim() !== 'Registered') {
          await run('az', ['provider', 'register', '-n', 'Microsoft.ContainerRegistry', '--wait'], { onLine: log });
        }
        if (!(await ok('az', ['acr', 'show', '-n', acr]))) {
          await run('az', ['acr', 'create', '-g', g, '-n', acr, '--sku', 'Basic', '--tags', ...LAB_TAGS], { onLine: log });
        }
        await run('az', ['aks', 'update', '-g', g, '-n', cluster, '--attach-acr', acr], { onLine: log });
        await run('az', ['acr', 'login', '-n', acr]);
        return `${acr}.azurecr.io/n8n`;
      },
      async remove(cluster, log) {
        const acr = `lab${owner.replace(/-/g, '')}${(await run('az', ['account', 'show', '--query', 'id', '-o', 'tsv'])).trim().slice(0, 6)}`.slice(0, 50);
        await run('az', ['acr', 'delete', '-n', acr, '--yes'], { onLine: log });
      },
    },
    async destroy(name, log) {
      await run('az', ['group', 'delete', '-n', group(name), '--yes'], { onLine: log });
    },
  };
}

export function getProvider(name: string): Provider {
  if (name === 'minikube') return minikube;
  if (name === 'aws') return eks();
  if (name === 'azure') return aks();
  throw new UserError(`Unknown provider '${name}'. Providers: minikube, aws, azure`);
}
