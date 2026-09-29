"""Pinned public record: independently identify status edges and read every output column."""
import argparse, csv, hashlib, json, math, subprocess
from datetime import datetime, timezone
from pathlib import Path
import comtrade
import pyarrow as pa
import pyarrow.ipc as ipc

ROOT = Path(__file__).resolve().parents[1]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def run(args, expected=0):
    p = subprocess.run(['node', 'bin/status-window.mjs', *map(str,args)], cwd=ROOT,
                       capture_output=True, text=True, encoding='utf-8', timeout=30)
    assert p.returncode == expected, (args,p.returncode,p.stdout,p.stderr)
    return json.loads(p.stdout) if expected == 0 else p
def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--cfg',type=Path,required=True); ap.add_argument('--dat',type=Path,required=True)
    ap.add_argument('--out',type=Path,required=True)
    args=ap.parse_args(); cfg=args.cfg.resolve(); dat=args.dat.resolve(); out=args.out.resolve()
    assert sha(cfg)=='656bc0a07bb4c422bd4bd3e14fd607dfd668fe8d0362c28c4c95e73096f36de2'
    assert sha(dat)=='e968ea9567684117d189e74dec622bf417ead6f2611105a82a6f6c5029185253'
    out.mkdir(exist_ok=False)
    rec=comtrade.Comtrade(use_double_precision=True); rec.load(str(cfg),str(dat))
    raw=list(csv.reader(dat.open())); cfgrows=list(csv.reader(cfg.open()))
    expected=[]
    for i in range(1,len(rec.time)):
        for ch in range(rec.status_count):
            old,new=bool(rec.status[ch][i-1]),bool(rec.status[ch][i])
            if old!=new:
                expected.append(dict(channel_number=int(cfgrows[2+rec.analog_count+ch][0]),sample_number=i+1,
                                     previous_sample_number=i,time_seconds=rec.time[i],before=old,after=new))
    actual=run(['scan',cfg,dat,0,7])
    assert len(expected)==4 and len(actual['events'])==4
    for a,e in zip(actual['events'],expected):
        assert math.isclose(a['time_seconds'],e['time_seconds'],abs_tol=1e-12)
        assert {k:v for k,v in a.items() if k!='time_seconds'}=={k:v for k,v in e.items() if k!='time_seconds'}
    outputs=[]
    for num,event in enumerate(expected):
        sample=event['sample_number']; channel=event['channel_number']; target=out/f'event-{num}.arrow'
        receipt=run(['export',cfg,dat,target,channel,sample,16,16])
        table=ipc.open_file(str(target)).read_all()
        assert table.num_rows==33 and table.num_columns==40
        indices=list(range(sample-1-16,sample+16))
        assert table['sample_number'].to_pylist()==[i+1 for i in indices]
        assert table['raw_ticks'].to_pylist()==[int(raw[i][1]) for i in indices]
        for row,i in enumerate(indices):
            assert math.isclose(table['relative_seconds'][row].as_py(),rec.time[i],abs_tol=1e-12)
            for ch in range(rec.analog_count):
                assert table[f'analog_{ch+1:03}_raw'][row].as_py()==float(raw[i][2+ch])
                assert math.isclose(table[f'analog_{ch+1:03}_scaled'][row].as_py(),rec.analog[ch][i],rel_tol=2e-12,abs_tol=2e-12)
            for ch in range(rec.status_count):
                assert table[f'status_{ch+1:03}'][row].as_py()==bool(rec.status[ch][i])
        field=table.schema.field('analog_001_scaled').metadata
        assert field[b'pors']==cfgrows[2][12].strip().encode()
        assert b'declared side' in field[b'value_semantics']
        digest=sha(target); run(['export',cfg,dat,target,channel,sample,16,16],2); assert sha(target)==digest
        outputs.append(dict(sample=sample,channel=channel,rows=33,columns=40,sha256=digest,receipt=receipt))
    absent=out/'must-not-exist.arrow'
    run(['export',cfg,dat,absent,1,2,0,0],2); assert not absent.exists()
    run(['export',cfg,dat,absent,1,1480,2000,0],2); assert not absent.exists()
    failure=run(['scan',cfg,dat,0,7,1],2); assert failure.stdout==''
    result=dict(utc=datetime.now(timezone.utc).isoformat(),sourceCfgSha256=sha(cfg),sourceDatSha256=sha(dat),
                independentReaders={'comtrade':'0.1.2','pyarrow':pa.__version__},events=expected,outputs=outputs,
                checks=['4 independently located transitions','4 exact 33-row windows; every column compared',
                        'no first-row inference','false edge and unavailable context publish nothing','event budget rejects, not truncates','existing output preserved'],
                limits=['one public recording','no fault diagnosis or UTC alignment','no external adoption claim'])
    (out/'receipt.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'events':len(expected),'windows':len(outputs),'comparedCells':4*33*40,'receipt':str(out/'receipt.json')}))
if __name__=='__main__':main()
