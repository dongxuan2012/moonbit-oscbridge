#!/usr/bin/env node
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, readFileSync, unlinkSync, rmdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const examples = dirname(fileURLToPath(import.meta.url));
const repo = dirname(examples);
const scratch = mkdtempSync(join(tmpdir(), 'oscbridge-example-'));
const output = join(scratch, 'window.arrow');
try {
  const stdout = execFileSync(process.execPath, [
    join(repo, 'bin/oscbridge.mjs'), 'export',
    join(examples, 'small.cfg'), join(examples, 'small.dat'),
    output, '0.001', '0.002', '2',
  ], {cwd: repo, encoding: 'utf8'});
  const receipt = JSON.parse(stdout);
  const bytes = readFileSync(output);
  assert.equal(receipt.output, output);
  assert.equal(receipt.window.boundary, '[start,end)');
  assert.equal(receipt.window.startSeconds, 0.001);
  assert.equal(receipt.window.endSeconds, 0.002);
  assert.equal(receipt.bytes, bytes.length);
  assert.equal(bytes.subarray(0, 6).toString('ascii'), 'ARROW1');
  assert.equal(bytes.subarray(-6).toString('ascii'), 'ARROW1');
  console.log(`Created a one-row Arrow window (${bytes.length} bytes).`);
} finally {
  try { unlinkSync(output); } catch (error) { if (error.code !== 'ENOENT') throw error; }
  rmdirSync(scratch);
}
