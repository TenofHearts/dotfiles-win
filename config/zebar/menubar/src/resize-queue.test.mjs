import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createResizeQueue } from './resize-queue.mjs';

test('rapid dropdown changes serialize and end closed', async () => {
  let release;
  const calls = [];
  const queue = createResizeQueue(async size => {
    calls.push(size);
    if (calls.length === 1) await new Promise(resolve => { release = resolve; });
  });
  const pending = queue.request(200);
  queue.request(300);
  queue.request(28);
  release();
  await pending;
  assert.deepEqual(calls, [200, 28]);
});
test('a failed size is retried instead of cached as successful', async () => {
  let calls = 0;
  const queue = createResizeQueue(async () => { if (++calls === 1) throw Error('display changed'); }, () => {});
  await queue.request(200);
  await queue.request(200);
  assert.equal(calls, 2);
});
test('disposal prevents queued native calls', async () => {
  let release;
  const calls = [];
  const queue = createResizeQueue(async size => { calls.push(size); await new Promise(resolve => { release = resolve; }); });
  const pending = queue.request(200);
  queue.request(28);
  queue.dispose();
  release();
  await pending;
  assert.deepEqual(calls, [200]);
});
