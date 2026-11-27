/**
 * listr2 does not fail the top-level run when a subtask fails, so every step and check records its failure here
 * and the command turns the list into an exit code. A failure names the target (or other scope) and the step.
 */
export interface Failure {
  scope: string;
  step: string;
}

const recorded: Failure[] = [];

export const recordFailure = (scope: string, step: string) => void recorded.push({ scope, step });
export const failures = (): readonly Failure[] => recorded;
export const failedScopes = (): Set<string> => new Set(recorded.map((f) => f.scope));
export const describeFailure = (f: Failure) => `${f.scope}: ${f.step}`;
