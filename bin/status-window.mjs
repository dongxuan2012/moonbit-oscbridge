#!/usr/bin/env node
import {createHash} from 'node:crypto';
import {readText,publishNew} from './oscbridge.mjs';
import {status_events,export_transition_ipc} from '../_build/js/release/build/cmd/arrow/arrow.js';
const usage='scan CFG DAT START END [MAX_EVENTS] | export CFG DAT OUT.arrow CHANNEL SAMPLE BEFORE_ROWS AFTER_ROWS [MAX_ROWS]';
const integer=(text,min,max)=>{if(!/^\d+$/.test(text))throw Error('Expected an integer');const n=Number(text);if(!Number.isSafeInteger(n)||n<min||n>max)throw Error('Integer out of range');return n;};
const decimal=text=>{if(!/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?$/i.test(text)||!Number.isFinite(Number(text)))throw Error('Expected finite seconds');return Number(text);};
const hash=x=>createHash('sha256').update(x).digest('hex');
try{
 const [mode,cfgPath,datPath,...args]=process.argv.slice(2);
 if(!['scan','export'].includes(mode)||!cfgPath||!datPath)throw Error(usage);
 if(mode==='scan'&&(args.length<2||args.length>3)||mode==='export'&&(args.length<5||args.length>6))throw Error(usage);
 const cfg=readText(cfgPath,1024*1024),dat=readText(datPath,32*1024*1024);
 const source={cfgSha256:cfg.sha256,datSha256:dat.sha256};
 if(mode==='scan'){
  const events=JSON.parse(status_events(cfg.text,dat.text,decimal(args[0]),decimal(args[1]),integer(args[2]??'1000',1,10000)));
  console.log(JSON.stringify({source,events,meaning:'observed adjacent status changes; no inferred first-row edge or fault diagnosis'},null,2));
 }else{
  const [out,c,s,pre,post,limit='10000']=args;
  const channel=integer(c,1,2147483647),sample=integer(s,2,200000),before=integer(pre,0,200000),after=integer(post,0,200000),maxRows=integer(limit,1,200000);
  const bytes=Buffer.from(export_transition_ipc(cfg.text,dat.text,channel,sample,before,after,maxRows));
  if(bytes.length<12||bytes.length>64*1024*1024||bytes.subarray(0,6).toString()!=='ARROW1'||bytes.subarray(-6).toString()!=='ARROW1')throw Error('Invalid IPC result');
  const output=publishNew(out,bytes);
  console.log(JSON.stringify({source,output,sha256:hash(bytes),channel,sample,beforeRows:before,afterRows:after,rows:before+after+1},null,2));
 }
}catch(error){console.error(error.message);process.exitCode=2;}
