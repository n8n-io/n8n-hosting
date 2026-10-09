import type { Env } from '../../cluster/kube.ts';
import type { Options } from '../options.ts';

/** A command gets the environment, the words after its name, and every option. */
export type Command = (env: Env, args: string[], opts: Options) => Promise<void>;
