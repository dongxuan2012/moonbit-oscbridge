import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const scan=spawnSync(process.execPath,['bin/status-window.mjs','scan','examples/small.cfg','examples/small.dat','0','1'],{cwd:root,encoding:'utf8'});
assert.equal(scan.status,0,scan.stderr);const {events}=JSON.parse(scan.stdout);assert.equal(events.length,1);assert.equal(events[0].sample_number,2);
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'osc-status-'));
try{
 const out=path.join(temp,'event.arrow');
 const result=spawnSync(process.execPath,['bin/status-window.mjs','export','examples/small.cfg','examples/small.dat',out,String(events[0].channel_number),'2','1','0'],{cwd:root,encoding:'utf8'});
 assert.equal(result.status,0,result.stderr);assert.equal(JSON.parse(result.stdout).rows,2);assert.equal(fs.readFileSync(out).subarray(0,6).toString(),'ARROW1');
 console.log('Observed a status edge and exported its two-sample context.');
}finally{assert(path.resolve(temp).startsWith(path.resolve(os.tmpdir())+path.sep));fs.rmSync(temp,{recursive:true,force:true});}
