import { resolve } from 'node:path';
import { parseArgs } from 'node:util';
import { UserError } from './ui.ts';

/** Everything typed on the command line. */
export interface Options {
  command?: string;
  args: string[];
  help: boolean;
  yes: boolean;
  e2e: boolean;
  provider?: string;
  cluster?: string;
  from?: string;
  to?: string;
  addons: string[];
  /** --env KEY=VALUE, as a map. */
  env: Record<string, string>;
  valuesFiles: string[];
}

/** `--env KEY=VALUE` pairs as a map. */
export function parseEnvPairs(pairs: string[] = []): Record<string, string> {
  return Object.fromEntries(
    pairs.map((pair) => {
      const i = pair.indexOf('=');
      if (i < 1) throw new UserError(`--env wants KEY=VALUE, got '${pair}'`);
      return [pair.slice(0, i), pair.slice(i + 1)];
    }),
  );
}

export function parseOptions(argv: string[] = process.argv.slice(2)): Options {
  const { values, positionals } = parseArgs({
    args: argv,
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
  const [command, ...args] = positionals;
  return {
    command,
    args,
    help: !!values.help,
    yes: !!values.yes,
    e2e: !!values.e2e,
    provider: values.provider,
    cluster: values.cluster,
    from: values.from,
    to: values.to,
    addons: values.addon ?? [],
    env: parseEnvPairs(values.env),
    valuesFiles: (values.values ?? []).map((f) => resolve(f)),
  };
}
