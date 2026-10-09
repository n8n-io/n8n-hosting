import type { Addon } from '../addons.ts';
import { ALL_TARGETS, DESCRIPTION } from '../targets/index.ts';
import { c } from '../support/ui.ts';

const ENV_VARS = [
  ['HOSTING', 'n8n-hosting checkout to deploy from (default: the repo the lab sits in, else ~/git/n8n-hosting)'],
  ['CHART', 'chart path (default $HOSTING/charts/n8n)'],
  ['N8N_IMAGE', 'image to deploy. On a cloud provider it must be in a registry'],
  ['N8N_TAG', 'image tag'],
  ['N8N_LICENSE_KEY', 'Enterprise key for multimain and licensed examples'],
  ['LAB_ADDONS', 'addons to load, separated by colons, same as --addon'],
  ['AWS_REGION', 'aws provider: region (default: the AWS CLI config)'],
  ['AZURE_LOCATION', 'azure provider: region (default: the Azure CLI config)'],
  ['LAB_AZURE_NODE_SIZE', 'azure provider: node size (default Standard_B2ms), LAB_AZURE_NODES for the count'],
  ['LAB_AWS_NODE_TYPE', 'aws provider: node type (default t3.large), LAB_AWS_NODES for the count (default 1)'],
  ['LAB_PROVIDER', 'default provider, same as --provider'],
];

const EXAMPLES = [
  ['./lab up queue', 'queue mode on minikube'],
  ['./lab up k8s queue --env N8N_LOG_LEVEL=debug', 'two targets, with an extra n8n setting'],
  ['HOSTING=~/git/n8n-hosting-wt-fix ./lab up queue', 'test a chart change from a worktree'],
  ['N8N_IMAGE=n8n-my-branch N8N_TAG=latest ./lab up k8s', 'test an unreleased n8n branch (see build-image.sh)'],
  ['AWS_REGION=eu-west-1 ./lab up queue --provider aws', 'run on an EKS cluster'],
  ['./lab down', 'remove everything'],
];

const addonCommands = (addons: Addon[]) =>
  addons
    .filter((a) => a.commands)
    .flatMap((a) => [`\n  ${c.dim(a.name)}`, ...Object.entries(a.commands!).map(([name, cmd]) => `  ${name.padEnd(20)}${cmd.help}`)])
    .join('\n');

export function helpText(addons: Addon[]): string {
  const text = `${c.bold('n8n hosting lab')}  ${c.dim('deploy n8n the way the n8n-hosting files deploy it')}

${c.bold('Usage')}  ./lab <command> [targets...] [options]

${c.bold('Commands')}
  up [targets...]     create or update targets ${c.dim('(safe to rerun; no target = single queue webhooks multimain)')}
  down [targets...]   remove targets ${c.dim('(no target = every deployment; the cluster stays)')}
  status              pods per namespace, and what a cloud cluster is costing

  ${c.dim('Clusters')}
  clusters            list the clusters you have for the provider
  cluster delete <n>  destroy a cluster and everything in it

  registry [delete]   create a registry the cluster can pull from, log Docker in, print where to push ${c.dim('(cloud only)')}

  ${c.dim('Deployments')}
  check [targets...]  smoke-test deployed targets: health, readiness, editor, webhook route (--e2e: run a workflow too)
  upgrade <target>    install --from a version, upgrade it, and check nothing broke

${c.bold('Options')}
  --env KEY=VALUE     up: an extra n8n setting for every target. Repeat it. n8n diagnostics are off unless you set them
  --values <file>     up: a Helm values file laid over the lab's own. Repeat it
  --addon <name|path> load an addon: a folder in addons/ or a path. Repeat it. Also LAB_ADDONS
  --e2e               check: also run a workflow through a webhook and read the result
  --from, --to <v>    upgrade: the n8n versions. --to defaults to the version the files ship with
  --provider <name>   minikube (default), aws or azure. Also LAB_PROVIDER
  --cluster <name>    use or create this cluster. Without it, up lists yours and asks
  -y, --yes           skip the confirmation before creating or deleting a cluster

${c.bold('Targets')}
${ALL_TARGETS.map((t) => `  ${t.padEnd(34)}${c.dim(DESCRIPTION[t])}`).join('\n')}
  ${'example-<name>'.padEnd(34)}${c.dim('a chart example, charts/n8n/examples/<name>.yaml')}

${c.bold('Examples')}
${EXAMPLES.map(([cmd, what]) => `  ${c.dim('# ' + what)}\n  ${c.dim('$')} ${c.cyan(cmd)}`).join('\n\n')}

${c.bold('Environment')}
${ENV_VARS.map(([name, what]) => `  ${name.padEnd(21)}${c.dim(what)}`).join('\n')}
`;
  return addons.some((a) => a.commands) ? `${text}\n${c.bold('Addon commands')}${addonCommands(addons)}\n` : text;
}
