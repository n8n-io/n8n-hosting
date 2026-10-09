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

/**
 * Turns a stream of chunks into whole lines. A line that arrives in two chunks is held until its end shows up, so
 * a reader never sees half of one. `\r` ends a line too, because progress output redraws with it.
 */
export function lineBuffer(onLine: (line: string) => void) {
  let rest = '';
  const emit = (line: string) => line.trim() && onLine(line.trim());
  return {
    push(chunk: string) {
      const parts = (rest + chunk).split(/\r\n|\n|\r/);
      rest = parts.pop() ?? '';
      parts.forEach(emit);
    },
    flush() {
      emit(rest);
      rest = '';
    },
  };
}

/** Runs a command, resolves with stdout. Secrets go in `input`, never in args. */
export function run(cmd: string, args: string[], opts: RunOpts = {}): Promise<string> {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, { stdio: ['pipe', 'pipe', 'pipe'], env: { ...process.env, ...opts.env } });
    let out = '';
    let err = '';
    const stdoutLines = lineBuffer((l) => opts.onLine?.(l));
    const stderrLines = lineBuffer((l) => opts.onLine?.(l));
    p.stdout.on('data', (d: Buffer) => ((out += d), stdoutLines.push(d.toString())));
    p.stderr.on('data', (d: Buffer) => ((err += d), stderrLines.push(d.toString())));
    p.on('error', (e: NodeJS.ErrnoException) => reject(e.code === 'ENOENT' ? new Error(`${cmd} is not installed`) : e));
    p.on('close', (code) => (stdoutLines.flush(), stderrLines.flush(), code === 0 ? resolve(out) : reject(new CmdError(cmd, code, err || out))));
    p.stdin.on('error', () => {}); // the command may exit before reading its input
    p.stdin.end(opts.input ?? '');
  });
}

export const ok = (cmd: string, args: string[]) => run(cmd, args).then(() => true, () => false);
export const has = (bin: string) => ok('which', [bin]);
