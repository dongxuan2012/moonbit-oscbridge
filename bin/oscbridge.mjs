#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {createHash, randomUUID} from 'node:crypto';

const CFG_LIMIT = 1024 * 1024;
const DAT_LIMIT = 32 * 1024 * 1024;
const IPC_LIMIT = 64 * 1024 * 1024;
const hash = value => createHash('sha256').update(value).digest('hex');

// Bound the read on one descriptor. Same-size concurrent rewrites are outside
// this helper's snapshot guarantee; callers must supply stable input files.
function readText(filename, limit) {
  const fd = fs.openSync(filename, 'r');
  try {
    const before = fs.fstatSync(fd);
    if (!before.isFile()) throw Error('输入必须是普通文件');
    if (before.size > limit) throw Error(`输入超过 ${limit} 字节限制`);
    const buffer = Buffer.alloc(before.size + 1);
    let count = 0;
    while (count < buffer.length) {
      const read = fs.readSync(fd, buffer, count, buffer.length - count, null);
      if (read === 0) break;
      count += read;
    }
    const after = fs.fstatSync(fd);
    if (count !== before.size || after.size !== before.size || after.mtimeMs !== before.mtimeMs) {
      throw Error('读取期间输入发生变化，请使用稳定文件');
    }
    const bytes = buffer.subarray(0, count);
    return {text: new TextDecoder('utf-8', {fatal: true}).decode(bytes), bytes: count, sha256: hash(bytes)};
  } finally {
    fs.closeSync(fd);
  }
}

function finiteDecimal(text, name) {
  if (!/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/.test(text)) {
    throw Error(`${name}必须是有限十进制数`);
  }
  const value = Number(text);
  if (!Number.isFinite(value)) throw Error(`${name}必须是有限十进制数`);
  return value;
}

// Write fully before publishing a new filename. linkSync fails if the target
// already exists; unlike rename, it cannot replace a user file on POSIX.
// This is local-file publication, not a directory-fsync crash-durability claim.
function publishNew(filename, bytes) {
  const resolved = path.resolve(filename);
  const directory = fs.realpathSync(path.dirname(resolved));
  const destination = path.join(directory, path.basename(resolved));
  const staging = path.join(directory, `.oscbridge-${randomUUID()}.partial`);
  let fd;
  let created = false;
  try {
    fd = fs.openSync(staging, 'wx', 0o600);
    created = true;
    fs.writeFileSync(fd, bytes);
    fs.fsyncSync(fd);
    fs.closeSync(fd);
    fd = undefined;
    fs.linkSync(staging, destination);
    return destination;
  } finally {
    if (fd !== undefined) fs.closeSync(fd);
    if (created) fs.unlinkSync(staging);
  }
}

const usage = '用法: node bin/oscbridge.mjs export CFG DAT OUT.arrow START_SECONDS END_SECONDS [MAX_ROWS]';

try {
  const args = process.argv.slice(2);
  if (args.length === 1 && args[0] === '--help') {
    console.log(usage);
  } else {
    if (args[0] !== 'export' || (args.length !== 6 && args.length !== 7)) throw Error(usage);
    const [, cfgPath, datPath, output, startText, endText, maxRowsText = '10000'] = args;
    const start = finiteDecimal(startText, '窗口起点');
    const end = finiteDecimal(endText, '窗口终点');
    if (start > end) throw Error('窗口起点不能大于终点');
    if (!/^[1-9]\d*$/.test(maxRowsText)) throw Error('MAX_ROWS必须是1至200000的整数');
    const maxRows = Number(maxRowsText);
    if (!Number.isSafeInteger(maxRows) || maxRows > 200000) throw Error('MAX_ROWS必须是1至200000的整数');
    // Check early for a useful error, but linkSync is the authoritative
    // no-replacement check even if a competing creator appears afterward.
    try {
      fs.lstatSync(output);
      throw Error('输出路径已存在；请选择新路径');
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    const cfg = readText(cfgPath, CFG_LIMIT);
    const dat = readText(datPath, DAT_LIMIT);
    const {export_arrow_ipc} = await import('../_build/js/release/build/cmd/arrow/arrow.js');
    const ipc = export_arrow_ipc(cfg.text, dat.text, start, end, maxRows);
    if (!(ipc instanceof Uint8Array) || ipc.byteLength > IPC_LIMIT) throw Error('编译核心返回的IPC无效或超过64MiB');
    const bytes = Buffer.from(ipc.buffer, ipc.byteOffset, ipc.byteLength);
    if (bytes.length < 12 || bytes.subarray(0, 6).toString('ascii') !== 'ARROW1' || bytes.subarray(-6).toString('ascii') !== 'ARROW1') {
      throw Error('编译核心未返回Arrow文件');
    }
    const destination = publishNew(output, bytes);
    console.log(JSON.stringify({
      output: destination, bytes: bytes.length, sha256: hash(bytes),
      source: {cfg: {bytes: cfg.bytes, sha256: cfg.sha256}, dat: {bytes: dat.bytes, sha256: dat.sha256}},
      window: {startSeconds: start, endSeconds: end, boundary: '[start,end)', maxRows},
      profile: 'Bounded COMTRADE-1999 ASCII input; declared-side physical values; no absolute-time claim',
    }, null, 2));
  }
} catch (error) {
  console.error(error?.message || String(error));
  process.exitCode = 2;
}
