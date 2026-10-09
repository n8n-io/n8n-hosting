import { spawn } from 'node:child_process';

export class CmdError extends Error {
  constructor(cmd: string, code: number | null, stderr: string) {
    super(`${cmd} failed (exit ${code})\n${stderr.trim().split('\n').slice(-12).join('\n')}`);
  }
}

export interface RunOpts {
  input?: string;
  env?: Record<string, string>;
  onLine?: (line: string) => void;
}

/** Runs a command, resolves with stdout. Secrets go in `input`, never in args. */
export function run(cmd: string, args: string[], opts: RunOpts = {}): Promise<string> {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, { stdio: ['pipe', 'pipe', 'pipe'], env: { ...process.env, ...opts.env } });
    let out = '';
    let err = '';
    const lines = (s: string) => opts.onLine && s.split('\n').forEach((l) => l.trim() && opts.onLine!(l.trim()));
    p.stdout.on('data', (d: Buffer) => ((out += d), lines(d.toString())));
    p.stderr.on('data', (d: Buffer) => ((err += d), lines(d.toString())));
    p.on('error', (e: NodeJS.ErrnoException) => reject(e.code === 'ENOENT' ? new Error(`${cmd} is not installed`) : e));
    p.on('close', (code) => (code === 0 ? resolve(out) : reject(new CmdError(cmd, code, err || out))));
    p.stdin.on('error', () => {}); // the command may exit before reading its input
    p.stdin.end(opts.input ?? '');
  });
}

export const ok = (cmd: string, args: string[]) => run(cmd, args).then(() => true, () => false);
export const has = (bin: string) => ok('which', [bin]);
