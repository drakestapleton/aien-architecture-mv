#!/usr/bin/env python3
"""Read-only byte-level zero-channel confirmation; no FP8 decoder or GPU."""
import json
import pathlib
import shlex
import subprocess

REMOTE = r'''
import hashlib,json,pathlib,struct
p=pathlib.Path('/home/drakestapleton/models/qwen3.6-35b-a3b-fp8-95a723d0/layers-0.safetensors')
zeros={};hashes={}
with p.open('rb') as f:
    n=struct.unpack('<Q',f.read(8))[0]
    header=json.loads(f.read(n))
    for proj in ('gate_proj','up_proj','down_proj'):
        key='model.language_model.layers.0.mlp.experts.0.'+proj+'.weight'
        m=header[key]
        assert m['dtype']=='F8_E4M3'
        rows,cols=m['shape']
        a,b=m['data_offsets']; f.seek(8+n+a); raw=f.read(b-a)
        assert len(raw)==rows*cols==b-a
        hashes[proj]=hashlib.sha256(raw).hexdigest()
        if proj=='down_proj':
            assert (rows,cols)==(2048,512)
            zeros[proj]=[j for j in range(cols) if all((raw[i*cols+j]&127)==0 for i in range(rows))]
        else:
            assert (rows,cols)==(512,2048)
            zeros[proj]=[i for i in range(rows) if all((v&127)==0 for v in raw[i*cols:(i+1)*cols])]
print(json.dumps({'zero_counts':{k:len(v) for k,v in zeros.items()},
 'identical_support':zeros['gate_proj']==zeros['up_proj']==zeros['down_proj'],
 'zero_indices':zeros['gate_proj'],'tensor_hashes':hashes}))
'''
result=json.loads(subprocess.check_output(['ssh','-o','BatchMode=yes','spark','python3 -c '+shlex.quote(REMOTE)]))
expected=json.loads(pathlib.Path(__file__).with_name('zero-support-byte-confirm.json').read_text())
assert result==expected, 'Checkpoint bytes/support changed since the original probe'
out={'verdict':'PASS','method':'raw E4M3 byte magnitude bits, independent of floating-point decoder',
     'scope':'one selected expert only; no generation or timing','result':result}
pathlib.Path(__file__).with_name('byte-confirm-replay.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps({k:out[k] for k in ('verdict','method','scope')}))
print(json.dumps(result['zero_counts']), 'identical_support=',result['identical_support'])
