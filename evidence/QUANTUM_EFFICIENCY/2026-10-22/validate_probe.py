#!/usr/bin/env python3
"""Independent CPU oracle checks of the throwaway probe, never inference.
Run: uv run --with numpy --with ml-dtypes validate_probe.py
Synthetic bytes only. No SSH, GPU, model loading, or timing.
"""
import base64
import hashlib
import json
import pathlib
from unittest.mock import patch
import numpy as np
import ml_dtypes
import weight_probe as probe


def payload(codes):
    name = 'model.language_model.layers.0.mlp.experts.0.gate_proj'
    raw = codes.tobytes()
    scale = np.array([0x3F80], dtype='<u2').tobytes()  # exact BF16 1
    return json.dumps({
        name+'.weight': {'meta': {'dtype': 'F8_E4M3', 'shape': [128, 128],
                                 'data_offsets': [0, len(raw)]},
                        'raw': base64.b64encode(raw).decode(),
                        'sha256': hashlib.sha256(raw).hexdigest()},
        name+'.weight_scale_inv': {'meta': {'dtype': 'BF16', 'shape': [1, 1],
                                           'data_offsets': [len(raw), len(raw)+2]},
                                  'raw': base64.b64encode(scale).decode(),
                                  'sha256': hashlib.sha256(scale).hexdigest()}
    }).encode()


finite = np.array([i for i in range(256) if i not in (127, 255)], dtype=np.uint8)
codes = np.resize(finite, (128, 128))
reference = codes.view(ml_dtypes.float8_e4m3fn).astype(np.float64)
with patch.object(probe.subprocess, 'check_output', return_value=payload(codes)):
    actual, _ = probe.fetch(0, 0, 'gate_proj')
assert np.array_equal(actual, reference)
assert np.array_equal(np.signbit(actual), np.signbit(reference))
refusals = []
for bad in (127, 255):
    broken = codes.copy()
    broken[0, 0] = bad
    with patch.object(probe.subprocess, 'check_output', return_value=payload(broken)):
        try:
            probe.fetch(0, 0, 'gate_proj')
        except AssertionError as exc:
            assert str(exc) == 'NaN FP8 code'
            refusals.append(bad)
        else:
            raise AssertionError('NaN decoder mutant escaped')
result = {'verdict': 'PASS', 'finite_fp8_codes_compared': len(finite),
          'signed_zero_checked': True, 'nan_codes_refused': refusals,
          'transform_controls': probe.selfcheck(), 'numpy': np.__version__,
          'ml_dtypes': ml_dtypes.__version__,
          'probe_sha256': hashlib.sha256(pathlib.Path(probe.__file__).read_bytes()).hexdigest(),
          'scope': 'Independent library FP8 oracle plus synthetic controls, not inference quality or speed'}
pathlib.Path(__file__).with_name('probe-validation.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result, indent=2))
