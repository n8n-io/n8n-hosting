#!/usr/bin/env node
import { resolve } from 'node:path';
import { parseArgs } from 'node:util';
import { Listr, type ListrTask } from 'listr2';
import { type Addon, loadAddons } from './addons.ts';
import { type Env, ensureDefaultStorageClass, envFromProcess, exists, kubectl, labNamespaces } from './kube.ts';
import { run as sh } from './sh.ts';
import { getProvider, requireClis } from './providers.ts';
import { ALL_TARGETS, COMPOSE_TARGETS, DEFAULT_TARGETS, DESCRIPTION, checkTargets, clusterTargets, failures, hasLicenseSecret, isCompose, licensed, namespaceOf, removeTargets, targetTask } from './targets.ts';
import { checkTask, deployedTargets, failed } from './check.ts';
import { e2eTask } from './e2e.ts';
import { upgradeTasks } from './upgrade.ts';
import { current, forget, pick, remember, use } from './clusters.ts';
import { UserError, ask, askHidden, c, confirm, table } from './ui.ts';

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

const HELP = `${c.bold('n8n hosting lab')}  ${c.dim('deploy n8n the way the n8n-hosting files deploy it')}

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

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    env: { type: 'string', multiple: true },
    values: { type: 'string', multiple: true },
    addon: { type: 'string', multiple: true },
    provider: { type: 'string' },
    cluster: { type: 'string' },
    yes: { type: 'boolean', short: 'y' },
    e2e: { type: 'boolean' },
    from: { type: 'string' },
    to: { type: 'string' },
    help: { type: 'boolean', short: 'h' },
  },
});
const [command, ...rest] = positionals;
let clusterName = '';

const addonHelp = (addons: Addon[]) =>
  addons.flatMap((a) => (a.commands ? [`\n  ${c.dim(a.name)}`, ...Object.entries(a.commands).map(([name, cmd]) => `  ${name.padEnd(20)}${cmd.help}`)] : [])).join('\n');

/** --env KEY=VALUE, as a map. */
function parseEnv(pairs: string[] = []): Record<string, string> {
  return Object.fromEntries(
    pairs.map((p) => {
      const i = p.indexOf('=');
      if (i < 1) throw new UserError(`--env wants KEY=VALUE, got '${p}'`);
      return [p.slice(0, i), p.slice(i + 1)];
    }),
  );
}

async function main() {
  const addons = await loadAddons([...(values.addon ?? []), ...(process.env.LAB_ADDONS?.split(':').filter(Boolean) ?? [])]);
  if (!command || values.help || command === 'help') return console.log(HELP + (addons.length ? `\n${c.bold('Addon commands')}${addonHelp(addons)}\n` : ''));
  const provider = getProvider(values.provider || process.env.LAB_PROVIDER || 'minikube');
  const env = envFromProcess(provider, addons, parseEnv(values.env), (values.values ?? []).map((f) => resolve(f)));

  console.log(`\n${c.bold('n8n hosting lab')}  ${c.dim('provider')} ${c.cyan(provider.name)}${addons.length ? `  ${c.dim('addons')} ${c.cyan(addons.map((a) => a.name).join(', '))}` : ''}\n`);
  await requireClis(provider);

  if (command === 'clusters') return clustersCommand(env);
  if (command === 'cluster') return clusterCommand(env, rest);
  if (command === 'up') return up(env, rest);

  const found = await use(provider, values.cluster);
  if (!found) {
    if (command === 'down') return console.log(c.dim(`No ${provider.name} cluster exists, nothing to remove.\n`));
    throw new UserError(`No ${provider.name} cluster exists. Create one with ./lab up`);
  }
  if (!found.running) throw new UserError(`Cluster ${found.name} is stopped. Start it with ./lab up --cluster ${found.name}`);
  clusterName = found.name;
  env.ctx = await provider.connect(found.name);
  if (command === 'down') return down(env, rest);
  if (command === 'registry') return registryCommand(env, rest);

  if (command === 'status') return status(env);
  if (command === 'check') return checkCommand(env, rest);
  if (command === 'upgrade') return upgradeCommand(env, rest);
  const addonCommand = addons.flatMap((a) => Object.entries(a.commands ?? {})).find(([name]) => name === command);
  if (addonCommand) return addonCommand[1].run(env, rest);
  throw new UserError(`Unknown command '${command}'. Run ./lab --help`);
}

function checkNames(env: Env, targets: string[]) {
  checkTargets(env, targets);
  return targets;
}

async function run(tasks: ListrTask[], opts: { concurrent?: boolean } = {}) {
  const list = new Listr(tasks, { concurrent: opts.concurrent ?? false, exitOnError: false, collectErrors: true, rendererOptions: { collapseSubtasks: false, collapseErrors: false } });
  await list.run();
  if (list.errors?.length) throw new UserError('Something failed, see above.');
}

async function up(env: Env, args: string[]) {
  const targets = checkNames(env, args.length ? args : DEFAULT_TARGETS);
  const { provider } = env;

  const choice = await pick(provider, values.cluster);
  const found = (await provider.list()).find((e) => e.name === choice.name);
  const needsCreate = choice.isNew || !found?.running;
  if (needsCreate && !provider.local) {
    console.log(`${c.yellow('This creates a cloud cluster that costs money.')}\n${c.dim((await provider.plan?.(choice.name)) ?? '')}\n`);
    if (!values.yes && !(await confirm('Create it?'))) throw new UserError('Cancelled. Pass --yes to skip this question.');
  }
  clusterName = choice.name;
  await run([
    {
      title: `${provider.name} cluster ${choice.name}`,
      task: async (_, task) => {
        if (needsCreate) {
          // A cluster takes minutes to create, so show how long it has been and what it is doing.
          const started = Date.now();
          const tick = setInterval(() => {
            const s = Math.floor((Date.now() - started) / 1000);
            task.title = `${provider.name} cluster ${choice.name} ${c.dim(`${Math.floor(s / 60)}m ${String(s % 60).padStart(2, '0')}s`)}`;
          }, 1000);
          try {
            await provider.create(choice.name, (l) => (task.output = l));
          } finally {
            clearInterval(tick);
          }
        }
        env.ctx = await provider.connect(choice.name);
        if (!provider.local) await ensureDefaultStorageClass(env, (l) => (task.output = l));
        remember(provider, choice.name);
      },
    },
  ]);

  // Licensed targets need an Enterprise key, unless their namespace already holds one.
  const unlicensed: string[] = [];
  for (const t of targets.filter((t) => licensed(env, t))) if (!(await hasLicenseSecret(env, t))) unlicensed.push(t);
  if (unlicensed.length && !env.licenseKey && process.stdin.isTTY) {
    env.licenseKey = (await askHidden(`Enterprise licence key for ${unlicensed.join(', ')} ${c.dim('(Enter to skip)')}: `)) || undefined;
  }
  if (unlicensed.length && !env.licenseKey) {
    console.log(c.yellow(`Skipping ${unlicensed.join(', ')}: no licence key.\n`));
    for (const t of unlicensed) targets.splice(targets.indexOf(t), 1);
  }

  const tasks: ListrTask[] = [];
  for (const a of env.addons.filter((a) => a.beforeUp)) tasks.push({ title: `${a.name} (addon)`, task: (_, task) => a.beforeUp!(env, (l) => (task.output = l)) });
  tasks.push({ title: 'Targets', task: (_, task) => task.newListr(targets.map((t) => targetTask(env, t)), { concurrent: true, exitOnError: false }) });
  for (const a of env.addons.filter((a) => a.afterUp)) tasks.push({ title: `${a.name} (addon, after)`, task: (_, task) => a.afterUp!(env, targets, (l) => (task.output = l)) });
  await run(tasks);

  const broken = new Set(failures.map((f) => f.split(':')[0]));
  const deployed = targets.filter((t) => !broken.has(t));
  if (broken.size) console.log(`\n${c.red(`${broken.size} of ${targets.length} targets failed:`)}\n${failures.map((f) => `  ${f}`).join('\n')}`);
  if (!deployed.length) throw new UserError('Nothing was deployed.');
  console.log(`\n${c.green(broken.size ? 'The rest deployed.' : 'Done.')}`);
  const cluster = deployed.filter((t) => !isCompose(t));
  if (cluster.length) console.log(c.dim('Open an editor with:'));
  for (const t of cluster) console.log(`  kubectl --context ${env.ctx} -n ${namespaceOf(t)} port-forward svc/${t === 'k8s' ? 'n8n' : 'n8n-main'} 5678`);
  // Compose targets publish no host port, so stacks can run side by side.
  const compose = deployed.filter(isCompose);
  if (compose.length) console.log(c.dim('Compose targets publish no port. Check one is healthy with:'));
  for (const t of compose) console.log(`  docker exec lab-${t}-n8n-1 wget -qO- http://localhost:5678/healthz`);
  console.log();
}

async function down(env: Env, args: string[]) {
  const all = args.length === 0;
  const targets = all ? [...(await clusterTargets(env)), ...(env.provider.local ? COMPOSE_TARGETS : [])] : checkNames(env, args);
  const { provider } = env;
  const tasks: ListrTask[] = [{ title: `Remove ${all ? 'all targets' : targets.join(', ')}`, task: (_, task) => removeTargets(env, targets, (l) => (task.output = l)) }];
  for (const a of env.addons.filter((a) => a.afterDown)) tasks.push({ title: `${a.name} (addon)`, task: (_, task) => a.afterDown!(env, all, (l) => (task.output = l)) });
  await run(tasks);
  console.log(`\n${c.green('Removed.')}`);
  // Deployments are gone, but the cluster is not. Say so, because a cloud cluster keeps costing money.
  if (provider.local) console.log(c.dim(`Cluster ${clusterName} is still running. ./lab cluster delete ${clusterName} removes it.\n`));
  else console.log(`${c.yellow(`Cluster ${clusterName} is still running and costing money.`)} ${c.dim(`Delete it with ./lab cluster delete ${clusterName}`)}\n`);
}

async function clustersCommand(env: Env) {
  const clusters = await env.provider.list();
  if (!clusters.length) return console.log(c.dim(`No ${env.provider.name} clusters. Create one with ./lab up\n`));
  const now = current(env.provider);
  console.log(table([['CLUSTER', 'STATE', 'CURRENT', 'DETAIL'], ...clusters.map((e) => [e.name, e.running ? c.green('running') : c.yellow('stopped'), e.name === now ? '*' : '', e.detail ?? ''])]) + '\n');
}

async function clusterCommand(env: Env, args: string[]) {
  const [action, name] = args;
  if (action !== 'delete' || !name) throw new UserError('Usage: ./lab cluster delete <name>');
  const { provider } = env;
  const target = provider.normalize?.(name) ?? name;
  if (!(await provider.list()).some((e) => e.name === target)) throw new UserError(`No ${provider.name} cluster named ${target}. See: ./lab clusters`);
  if (!values.yes && !(await confirm(`Delete the ${provider.name} cluster ${c.bold(target)} and everything in it?`))) throw new UserError('Cancelled. Pass --yes to skip this question.');
  // This list can hold your own clusters, so the name has to be typed, and --yes does not skip it.
  if (provider.shared && (await ask(`${provider.name} lists every cluster you have, not only the lab's. Type the name to confirm`, '')) !== target) throw new UserError('The name did not match. Cancelled.');
  await run([{ title: `Delete ${provider.name} cluster ${target}`, task: (_, task) => provider.destroy(target, (l) => (task.output = l)) }]);
  forget(provider, target);
  console.log(`\n${c.green('Deleted.')}\n`);
}

async function registryCommand(env: Env, args: string[]) {
  const { registry } = env.provider;
  if (!registry) throw new UserError(`The ${env.provider.name} provider has no registry. Local clusters use images loaded into them.`);
  if (args[0] === 'delete') {
    await run([{ title: 'Delete the registry', task: (_, task) => registry.remove(clusterName, (l) => (task.output = l)) }]);
    return console.log(`\n${c.green('Deleted.')}\n`);
  }
  let repo = '';
  await run([{ title: `Registry for ${provider(env)} cluster ${clusterName}`, task: async (_, task) => void (repo = await registry.ensure(clusterName, (l) => (task.output = l))) }]);
  console.log(`\n${c.green('Ready.')} Build and push an image, then deploy it:\n  ${c.cyan(`REGISTRY=${repo} ./build-image.sh <worktree> <name>`)}\n  ${c.cyan(`N8N_IMAGE=${repo} N8N_TAG=<name> ./lab up <target> --provider ${env.provider.name}`)}\n`);
}
const provider = (env: Env) => env.provider.name;

async function upgradeCommand(env: Env, args: string[]) {
  const [t] = checkNames(env, args.slice(0, 1));
  if (!t || args.length > 1) throw new UserError('Pass one target: ./lab upgrade queue --from 2.39.0');
  if (!values.from) throw new UserError('Pass the version to start from: --from <version>');
  await run(await upgradeTasks(env, t, values.from, values.to));
  if (failed.length || failures.length) throw new UserError(`Upgrade of ${t} failed: ${[...failures, ...failed].join(', ')}`);
  console.log(`\n${c.green('Upgrade passed.')} ${c.dim(`./lab down ${t} removes it.`)}\n`);
}

async function checkCommand(env: Env, args: string[]) {
  const targets = args.length ? checkNames(env, args) : await deployedTargets(env);
  if (!targets.length) throw new UserError('Nothing is deployed. Try ./lab up queue');
  await run(targets.map((t) => (values.e2e ? e2eTask(env, t, checkTask(env, t)) : checkTask(env, t))));
  if (failed.length) throw new UserError(`${failed.length} check${failed.length > 1 ? 's' : ''} failed: ${failed.join(', ')}`);
  console.log(`\n${c.green('All checks passed.')}\n`);
}

async function status(env: Env) {
  const info = await env.provider.info?.(clusterName).catch(() => '');
  console.log(`${c.bold('cluster')} ${clusterName} ${c.dim(info ?? '')}\n`);
  const namespaces = (await labNamespaces(env, true)).sort();
  let shown = false;
  for (const ns of namespaces) {
    if (!(await exists(env, 'ns', ns))) continue;
    shown = true;
    const { items } = JSON.parse(await kubectl(env, ['-n', ns, 'get', 'pods', '-o', 'json']));
    console.log(c.bold(ns));
    const rows = items.map((p: any) => {
      const statuses = p.status.containerStatuses ?? [];
      const ready = statuses.filter((s: any) => s.ready).length;
      const phase: string = p.status.phase;
      const color = phase === 'Running' && ready === statuses.length ? c.green : phase === 'Failed' ? c.red : c.yellow;
      return [p.metadata.name, `${ready}/${statuses.length}`, color(phase)];
    });
    console.log((rows.length ? table([['POD', 'READY', 'STATUS'], ...rows]).replace(/^/gm, '  ') : c.dim('  no pods')) + '\n');
  }
  for (const t of COMPOSE_TARGETS) {
    const out = await sh('docker', ['ps', '-a', '--filter', `label=com.docker.compose.project=lab-${t}`, '--format', '{{.Names}}\t{{.Status}}']);
    if (!out.trim()) continue;
    shown = true;
    console.log(`${c.bold(t)} ${c.dim('(docker compose)')}`);
    const rows = out.trim().split('\n').map((l) => {
      const [name, state] = l.split('\t');
      return [name, (state.startsWith('Up') ? c.green : c.yellow)(state)];
    });
    console.log(table([['CONTAINER', 'STATUS'], ...rows]).replace(/^/gm, '  ') + '\n');
  }
  if (!shown) console.log(c.dim('Nothing deployed. Try ./lab up queue\n'));
}

main().catch((e) => {
  console.error(`\n${c.red('✖')} ${e instanceof UserError ? e.message : e instanceof Error ? e.message : e}\n`);
  process.exit(1);
});
