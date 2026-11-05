"""Throwaway CPU-only representation probe, NOT an inference benchmark.
Reads three preselected real FP8 matrices over SSH; no GPU, model load, or writes
on Spark. Results contain hashes/statistics, never model weights. Reproduce:
OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 uv run --with numpy weight_probe.py
"""
import base64
import hashlib
import json
import pathlib
import platform
import shlex
import subprocess
import sys

import numpy as np

MODEL = '/home/drakestapleton/models/qwen3.6-35b-a3b-fp8-95a723d0'
SELECTION = [(0, 0, 'gate_proj'), (20, 128, 'up_proj'), (39, 255, 'down_proj')]


def fetch(layer, expert, proj):
    name = f'model.language_model.layers.{layer}.mlp.experts.{expert}.{proj}'
    code = '''import json,struct,pathlib,base64,hashlib
p=pathlib.Path(MODEL)/('layers-'+str(LAYER)+'.safetensors')
with p.open('rb') as f:
 n=struct.unpack('<Q',f.read(8))[0]; hdr=json.loads(f.read(n)); out={}
 for key in [NAME+'.weight',NAME+'.weight_scale_inv']:
  m=hdr[key];a,b=m['data_offsets'];f.seek(8+n+a);raw=f.read(b-a)
  assert len(raw)==b-a
  out[key]={'meta':m,'raw':base64.b64encode(raw).decode(),'sha256':hashlib.sha256(raw).hexdigest()}
print(json.dumps(out))
'''
    code = f'MODEL={MODEL!r};LAYER={layer!r};NAME={name!r}\n' + code
    raw = subprocess.check_output(['ssh', '-o', 'BatchMode=yes', 'spark', 'python3 -c ' + shlex.quote(code)])
    data = json.loads(raw)
    wt = data[name + '.weight']
    sc = data[name + '.weight_scale_inv']
    assert wt['meta']['dtype'] == 'F8_E4M3', wt['meta']
    codes = np.frombuffer(base64.b64decode(wt['raw']), dtype=np.uint8).reshape(wt['meta']['shape'])
    scales_raw = base64.b64decode(sc['raw'])
    if sc['meta']['dtype'] == 'F32':
        scales = np.frombuffer(scales_raw, dtype='<f4').astype(np.float64)
    elif sc['meta']['dtype'] == 'BF16':
        scales = (np.frombuffer(scales_raw, dtype='<u2').astype(np.uint32) << 16).view(np.float32).astype(np.float64)
    else:
        raise ValueError(sc['meta'])
    scales = scales.reshape(sc['meta']['shape'])
    assert np.all(np.isfinite(scales)) and np.all(scales > 0)
    exp = ((codes >> 3) & 15).astype(int)
    mant = (codes & 7).astype(int)
    assert not np.any((exp == 15) & (mant == 7)), 'NaN FP8 code'
    val = np.where(exp == 0, mant * 2.0**-9, (1 + mant/8) * np.exp2(exp - 7))
    val *= np.where(codes & 128, -1, 1)
    assert scales.shape == (val.shape[0]//128, val.shape[1]//128)
    val *= np.repeat(np.repeat(scales, 128, axis=0), 128, axis=1)
    provenance = {k: {a: v[a] for a in ('meta', 'sha256')} for k,v in data.items()}
    return val, provenance


def h128(arr):
    """Orthogonal 128-wide Sylvester Hadamard on contiguous row blocks."""
    shape = arr.shape
    out = arr.copy().reshape(-1, 128)
    step = 1
    while step < 128:
        view = out.reshape(-1, 128//(2*step), 2*step)
        left, right = view[..., :step].copy(), view[..., step:].copy()
        view[..., :step] = left + right
        view[..., step:] = left - right
        step *= 2
    return (out / np.sqrt(128)).reshape(shape)


def q4(arr):
    """Toy symmetric INT4, [-7,7], one f64 analysis scale per 128 weights.
    This is NOT NVFP4, GPTQ, QuaRot, SpinQuant or a deployable format.
    """
    shape = arr.shape
    blocks = arr.reshape(-1, 128)
    scale = np.max(np.abs(blocks), axis=1, keepdims=True)/7
    scale[scale == 0] = 1
    return (np.clip(np.rint(blocks/scale), -7, 7)*scale).reshape(shape)


def selfcheck():
    # Independent explicit Hadamard matrix and hand-coded FP8 known values.
    hh = np.array([[1.]])
    for _ in range(7):
        hh = np.block([[hh, hh], [hh, -hh]])
    hh /= np.sqrt(128)
    x = np.arange(256, dtype=np.float64).reshape(2,128)/17
    assert np.allclose(h128(x), x @ hh, rtol=0, atol=1e-12)
    assert np.allclose(h128(h128(x)), x, rtol=0, atol=1e-12)
    assert np.array_equal(q4(np.zeros((1,128))), np.zeros((1,128)))
    assert np.allclose(q4(np.ones((1,128))), 1)
    assert np.linalg.matrix_rank(np.outer(np.arange(1,5), np.arange(1,7))) == 1
    return 'PASS: independent explicit Hadamard, inverse, zero/constant quantizer, rank-one control'


def main():
    control = selfcheck()
    rows = []
    for layer, expert, proj in SELECTION:
        ww, provenance = fetch(layer, expert, proj)
        assert np.isfinite(ww).all()
        ss = np.linalg.svd(ww, compute_uv=False)
        norm = np.linalg.norm(ww)
        ss_energy = float(np.sum(ss*ss))
        assert np.isclose(ss_energy, norm*norm, rtol=1e-12)
        plain = float(np.linalg.norm(q4(ww)-ww)/norm)
        rotated = float(np.linalg.norm(h128(q4(h128(ww)))-ww)/norm)
        n,k = ww.shape
        row = {'layer':layer,'expert':expert,'projection':proj,'shape':[n,k],
               'provenance':provenance,'numerical_rank_tol_maxdim_eps':int(np.sum(ss > ss[0]*max(n,k)*np.finfo(float).eps)),
               'rank_relative_frobenius_error':{str(r):float(np.sqrt(np.sum(ss[r:]**2)/ss_energy)) for r in [64,128,204,256,409]},
               'toy_int4_relative_frobenius_error':plain,'block_hadamard_toy_int4_relative_frobenius_error':rotated,
               'rotation_error_ratio':rotated/plain,
               'same_dtype_rank64_entry_ratio':64*(n+k)/(n*k),
               'bf16_rank64_vs_fp8_dense_byte_ratio_no_metadata':2*64*(n+k)/(n*k)}
        rows.append(row)
        print(json.dumps(row),flush=True)
    result = {'verdict':'PARTIAL: feasibility evidence on three selected matrices, NOT model accuracy or speed',
              'scope':'Frozen predetermined first/middle/last layer and expert selection; not random or representative; existing FP8 checkpoint, not BF16 original. No timings collected.',
              'model_path':MODEL,'python':sys.version,'numpy':np.__version__,'platform':platform.platform(),
              'controls':control,'selection':SELECTION,'rows':rows}
    pathlib.Path(__file__).with_name('weight-probe-results.json').write_text(json.dumps(result,indent=2)+'\n')
    print(control)

if __name__ == '__main__':
    main()
