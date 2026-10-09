import { styleText } from 'node:util';
import { createInterface } from 'node:readline/promises';

export const c = {
  bold: (s: string) => styleText('bold', s),
  dim: (s: string) => styleText('dim', s),
  green: (s: string) => styleText('green', s),
  red: (s: string) => styleText('red', s),
  yellow: (s: string) => styleText('yellow', s),
  cyan: (s: string) => styleText('cyan', s),
};

const strip = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, '');

export function table(rows: string[][]): string {
  const widths = rows[0].map((_, i) => Math.max(...rows.map((r) => strip(r[i] ?? '').length)));
  return rows
    .map((r, n) => {
      const line = r.map((cell, i) => (i === r.length - 1 ? cell : cell + ' '.repeat(widths[i] - strip(cell).length))).join('  ');
      return n === 0 ? c.dim(line) : line;
    })
    .join('\n');
}

export async function confirm(question: string): Promise<boolean> {
  if (!process.stdin.isTTY) return false;
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  const answer = await rl.question(`${question} ${c.dim('[y/N]')} `);
  rl.close();
  return /^y(es)?$/i.test(answer.trim());
}

export function askHidden(question: string): Promise<string> {
  return new Promise((resolve) => {
    let value = '';
    process.stdout.write(question);
    process.stdin.setRawMode(true);
    process.stdin.resume();
    process.stdin.setEncoding('utf8');
    const onData = (chunk: string) => {
      for (const key of chunk) {
        if (key === '\r' || key === '\n') {
          process.stdin.setRawMode(false);
          process.stdin.pause();
          process.stdin.off('data', onData);
          process.stdout.write('\n');
          return resolve(value);
        }
        if (key === '\u0003') process.exit(130);
        value = key === '\u007f' ? value.slice(0, -1) : value + key;
      }
    };
    process.stdin.on('data', onData);
  });
}

export class UserError extends Error {}

/** A numbered list. Enter picks the default. */
export async function choose(question: string, options: string[], defaultIndex = 0): Promise<number> {
  console.log(`${c.bold(question)}`);
  options.forEach((o, i) => console.log(`  ${c.cyan(String(i + 1))}  ${o}`));
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  for (;;) {
    const answer = (await rl.question(`Choose ${c.dim(`[${defaultIndex + 1}]`)} `)).trim();
    const n = answer === '' ? defaultIndex + 1 : Number(answer);
    if (Number.isInteger(n) && n >= 1 && n <= options.length) {
      rl.close();
      return n - 1;
    }
  }
}

export async function ask(question: string, fallback: string): Promise<string> {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  const answer = (await rl.question(`${question} ${c.dim(`[${fallback}]`)} `)).trim();
  rl.close();
  return answer || fallback;
}
