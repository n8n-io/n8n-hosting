import { ok, run } from '../sh.ts';
import { UserError } from '../ui.ts';
import { LAB_TAG, isLabTag, labName, owner, runningFor } from './lab.ts';
import type { Log, Provider } from './types.ts';

const HOURLY = 'The control plane costs about $0.10 an hour, and each t3.large node about $0.09.';
const REPOSITORY = 'lab-n8n';

/** eksctl's lines are written for its own log. This turns the milestones into what a person is waiting for. */
export function friendly(line: string): string {
  const text = line.replace(/^\S+ \S+ \[\S+\]\s+/, '');
  if (/building cluster stack|creating cluster stack|waiting for CloudFormation stack "eksctl-.*-cluster"/i.test(text)) return 'Creating the control plane (about 10 minutes)';
  if (/nodegroup/i.test(text)) return 'Creating the node group (about 5 minutes)';
  if (/addon/i.test(text)) return 'Installing the storage addon';
  if (/saved kubeconfig|is ready/i.test(text)) return 'Cluster is ready';
  return text;
}

/** The eksctl config for a lab cluster: tagged, with OIDC and the EBS driver so volume claims work. */
export function clusterConfig(name: string, region: string, nodeType: string, nodes: number) {
  return {
    apiVersion: 'eksctl.io/v1alpha5',
    kind: 'ClusterConfig',
    metadata: { name, region, tags: { lab: LAB_TAG, owner } },
    iam: { withOIDC: true },
    managedNodeGroups: [{ name: 'lab', instanceType: nodeType, desiredCapacity: nodes, minSize: nodes, maxSize: nodes, volumeSize: 20 }],
    addons: [{ name: 'aws-ebs-csi-driver', wellKnownPolicies: { ebsCSIController: true } }],
  };
}

const aws = (args: string[], region?: string) => run('aws', region ? [...args, '--region', region] : args);

export function eks(): Provider {
  // The smallest setup that runs the lab: one node. Raise it for many targets at once.
  const nodeType = process.env.LAB_AWS_NODE_TYPE || 't3.large';
  const nodes = Number(process.env.LAB_AWS_NODES || 1);

  // AWS_REGION wins, then the region in the AWS CLI config.
  async function region(): Promise<string> {
    const found = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || (await run('aws', ['configure', 'get', 'region']).catch(() => '')).trim();
    if (!found) throw new UserError('Set AWS_REGION, for example: AWS_REGION=eu-west-1');
    return found;
  }

  async function requireCredentials(): Promise<void> {
    if (!(await ok('aws', ['sts', 'get-caller-identity']))) throw new UserError('AWS credentials are not valid. Run `aws sso login` or `aws configure`, then try again.');
  }

  /** A cluster is the lab's only when it carries the lab tag. The name prefix alone is not proof. */
  const isLabCluster = async (name: string, where: string) =>
    isLabTag((await aws(['eks', 'describe-cluster', '--name', name, '--query', 'cluster.tags.lab', '--output', 'text'], where).catch(() => '')).trim());

  /** The ECR repository's ARN, but only when it carries the lab tag. One repository per region. */
  async function labRepositoryArn(where: string): Promise<string | undefined> {
    const arn = (await aws(['ecr', 'describe-repositories', '--repository-names', REPOSITORY, '--query', 'repositories[0].repositoryArn', '--output', 'text'], where).catch(() => '')).trim();
    if (!arn) return undefined;
    const tag = (await aws(['ecr', 'list-tags-for-resource', '--resource-arn', arn, '--query', "tags[?Key=='lab'].Value | [0]", '--output', 'text'], where).catch(() => '')).trim();
    return isLabTag(tag) ? arn : undefined;
  }

  async function ensureRepository(log: Log): Promise<string> {
    const where = await region();
    const found = (await aws(['ecr', 'describe-repositories', '--repository-names', REPOSITORY, '--query', 'repositories[0].repositoryUri', '--output', 'text'], where).catch(() => '')).trim();
    if (found) return found;
    const created = await run('aws', ['ecr', 'create-repository', '--repository-name', REPOSITORY, '--region', where, '--tags', `Key=lab,Value=${LAB_TAG}`, `Key=owner,Value=${owner}`, '--query', 'repository.repositoryUri', '--output', 'text'], { onLine: log });
    return created.trim();
  }

  return {
    name: 'aws',
    local: false,
    clis: ['aws', 'eksctl'],
    defaultName: () => `lab-${owner}`,
    normalize: labName,
    async plan(name) {
      return `EKS cluster ${name} in ${await region()}: ${nodes} x ${nodeType}, 20 GB disk each.\n${HOURLY} Takes about 15 minutes.`;
    },
    async info(name) {
      const created = (await aws(['eks', 'describe-cluster', '--name', name, '--query', 'cluster.createdAt', '--output', 'text'], await region()).catch(() => '')).trim();
      return `${runningFor(created)}. ${HOURLY} Delete it when you are done: ./lab cluster delete ${name}`;
    },
    async list() {
      await requireCredentials();
      const where = await region();
      const out = await run('eksctl', ['get', 'cluster', '--region', where, '-o', 'json']).catch(() => '[]');
      const named = (JSON.parse(out) as { Name: string; Region?: string }[]).filter((c) => c.Name.startsWith('lab-'));
      const labels = await Promise.all(named.map((c) => isLabCluster(c.Name, where)));
      return named.filter((_, i) => labels[i]).map((c) => ({ name: c.Name, running: true, detail: c.Region ?? '' }));
    },
    async create(name, log) {
      const config = clusterConfig(name, await region(), nodeType, nodes);
      await run('eksctl', ['create', 'cluster', '-f', '-'], { input: JSON.stringify(config), onLine: (line) => log(friendly(line)) });
    },
    async connect(name) {
      // The provider is in the context name, so two providers' clusters with the same name never collide.
      const ctx = `aws-${name}`;
      await run('aws', ['eks', 'update-kubeconfig', '--name', name, '--region', await region(), '--alias', ctx]);
      return ctx;
    },
    // Managed node groups get read access to ECR in the same account.
    registry: {
      async ensure(_cluster, log) {
        const uri = await ensureRepository(log);
        const password = (await run('aws', ['ecr', 'get-login-password', '--region', await region()])).trim();
        await run('docker', ['login', '--username', 'AWS', '--password-stdin', uri.split('/')[0]], { input: password });
        return uri;
      },
      async remove(_cluster, log) {
        const where = await region();
        if (!(await labRepositoryArn(where))) throw new UserError(`The ${REPOSITORY} repository is not tagged as the lab's, so it is left alone.`);
        await run('aws', ['ecr', 'delete-repository', '--repository-name', REPOSITORY, '--force', '--region', where], { onLine: log });
      },
    },
    async destroy(name, log) {
      await run('eksctl', ['delete', 'cluster', '--name', name, '--region', await region(), '--wait'], { onLine: log });
    },
  };
}
