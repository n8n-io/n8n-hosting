import { Listr, type ListrTask } from 'listr2';
import { UserError } from './ui.ts';

/**
 * Runs tasks with a progress display. Any failure becomes one error, with the details already on screen.
 * `exitOnError` stops at the first failed task, for a sequence where each step needs the one before it.
 */
export async function runTasks(tasks: ListrTask[], opts: { concurrent?: boolean; exitOnError?: boolean } = {}): Promise<void> {
  const list = new Listr(tasks, { concurrent: opts.concurrent ?? false, exitOnError: opts.exitOnError ?? false, collectErrors: true, rendererOptions: { collapseSubtasks: false, collapseErrors: false } });
  await list.run();
  if (list.errors?.length) throw new UserError('Something failed, see above.');
}
