import assert from 'node:assert/strict';
import { test } from 'node:test';
import { retry } from '../src/testing/retry.ts';

test('retry returns the first success', async () => {
  let calls = 0;
  const result = await retry(async () => (++calls < 3 ? Promise.reject(new Error('not yet')) : 'ok'), { attempts: 5, delayMs: 1 });
  assert.equal(result, 'ok');
  assert.equal(calls, 3);
});

test('retry gives up after the attempts and throws the last error', async () => {
  let calls = 0;
  await assert.rejects(retry(async () => Promise.reject(new Error(`try ${++calls}`)), { attempts: 3, delayMs: 1 }), /try 3/);
  assert.equal(calls, 3);
});
