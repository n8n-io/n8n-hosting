import assert from 'node:assert/strict';
import { test } from 'node:test';
import { lineBuffer } from '../src/support/sh.ts';
import { typeInto } from '../src/support/ui.ts';

test('a line split across chunks reaches the reader whole', () => {
  const lines: string[] = [];
  const buffer = lineBuffer((l) => lines.push(l));
  buffer.push('first\nsec');
  buffer.push('ond\nthi');
  buffer.push('rd');
  assert.deepEqual(lines, ['first', 'second']);
  buffer.flush();
  assert.deepEqual(lines, ['first', 'second', 'third']);
});

test('carriage returns end a line, and blank lines are skipped', () => {
  const lines: string[] = [];
  const buffer = lineBuffer((l) => lines.push(l));
  buffer.push('10%\r50%\r\n\n  \ndone\n');
  assert.deepEqual(lines, ['10%', '50%', 'done']);
});

test('typing a hidden answer: backspace deletes, arrows are dropped, Enter submits', () => {
  assert.deepEqual(typeInto('', 'abc'), { value: 'abc', submitted: false });
  assert.equal(typeInto('abc', '\u007f').value, 'ab');
  assert.equal(typeInto('abc', '\b').value, 'ab');
  assert.equal(typeInto('ab', '\u001b[A').value, 'ab');
  assert.equal(typeInto('ab', 'c\u001b[D\u001b[Cd').value, 'abcd');
  assert.deepEqual(typeInto('key', '\r'), { value: 'key', submitted: true });
});
