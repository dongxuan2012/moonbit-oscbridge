#!/usr/bin/env node
// Exercise publication boundaries through real child processes, using a public
// input supplied by the caller. This is not a numerical reference reader.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';

const [cfgArg, datArg, workArg] = process.argv.slice(2);
assert(cfgArg && datArg && workArg, 'Usage: node bin/check-host.mjs CFG DAT EXISTING_WORK_DIRECTORY');
const cfg = path.resolve(cfgArg), dat = path.resolve(datArg);
const work = fs.mkdtempSync(path.join(fs.realpathSync(workArg), 'oscbridge-host-'));
const cli = fileURLToPath(new URL('./oscbridge.mjs', import.meta.url));
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const inputHashes = [sha(fs.readFileSync(cfg)), sha(fs.readFileSync(dat))];
const checks = [];
function run(name, cfgPath, datPath, destination, expectedCode, maxRows = '20000') {
  const args = [cli, 'export', cfgPath, datPath, destination, '1', '1.1', maxRows];
  const proc = spawnSync(process.execPath, args, {encoding: 'utf8', timeout: 30000, maxBuffer: 1024 * 1024});
  assert.equal(proc.error, undefined, `${name}: child failed to run: ${proc.error}`);
  assert.equal(proc.status, expectedCode, `${name}: ${proc.stderr}`);
  const partials = fs.readdirSync(work).filter(entry => entry.startsWith('.oscbridge-') && entry.endsWith('.partial'));
  assert.deepEqual(partials, [], `${name}: staging artifacts remained`);
  checks.push({name, expectedExit: expectedCode, actualExit: proc.status, stderr: proc.stderr.trim(),
    outputExists: fs.existsSync(destination)});
  return proc;
}

const valid = path.join(work, 'valid.arrow');
const first = run('valid public window publishes an IPC file', cfg, dat, valid, 0);
const receipt = JSON.parse(first.stdout);
assert.equal(receipt.sha256, sha(fs.readFileSync(valid)));
assert.equal(receipt.source.cfg.sha256, inputHashes[0]);
assert.equal(receipt.source.dat.sha256, inputHashes[1]);

const sentinel = path.join(work, 'existing.arrow');
const sentinelBytes = Buffer.from([0, 255, 91, 13, 10, 31]);
fs.writeFileSync(sentinel, sentinelBytes, {flag: 'wx'});
run('existing output remains byte-identical', cfg, dat, sentinel, 2);
assert.deepEqual(fs.readFileSync(sentinel), sentinelBytes);

run('output cannot overwrite the CFG input', cfg, dat, cfg, 2);

const malformed = path.join(work, 'missing-field.dat');
const rows = fs.readFileSync(dat, 'utf8').split('\n');
const firstFields = rows[0].trimEnd().split(',');
firstFields.pop();
rows[0] = firstFields.join(',');
fs.writeFileSync(malformed, rows.join('\n'), {flag: 'wx'});
const malformedOutput = path.join(work, 'malformed.arrow');
run('malformed record publishes no output', cfg, malformed, malformedOutput, 2);
assert.equal(fs.existsSync(malformedOutput), false);

const limitedOutput = path.join(work, 'too-many-rows.arrow');
run('window row budget failure publishes no output', cfg, dat, limitedOutput, 2, '159');
assert.equal(fs.existsSync(limitedOutput), false);

const badUtf8 = path.join(work, 'invalid-utf8.cfg');
fs.writeFileSync(badUtf8, Buffer.from([255]), {flag: 'wx'});
const badUtf8Output = path.join(work, 'invalid-utf8.arrow');
run('invalid UTF-8 publishes no output', badUtf8, dat, badUtf8Output, 2);
assert.equal(fs.existsSync(badUtf8Output), false);

assert.deepEqual([sha(fs.readFileSync(cfg)), sha(fs.readFileSync(dat))], inputHashes);
const report = {result: 'PASS', recordedAt: new Date().toISOString(), work, checks,
  inputsUnchanged: true, noStagingArtifacts: true,
  independentNumericReference: false,
  scope: 'Local child-process publication, no-overwrite and input/error boundaries; no power-loss durability or concurrent same-size input rewrite guarantee.'};
fs.writeFileSync(path.join(work, 'HOST-CHECKS.json'), JSON.stringify(report, null, 2) + '\n', {flag: 'wx'});
console.log(JSON.stringify(report, null, 2));
