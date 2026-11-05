"""Follow up an unexpected low numerical rank in the first selected expert.
Static checkpoint inspection only. Does not claim execution equivalence or speed.
"""
import json
import pathlib
import numpy as np
from weight_probe import fetch, SELECTION

rows = []
for layer, expert, proj in SELECTION + [(0,0,'up_proj'),(0,0,'down_proj')]:
    ww, provenance = fetch(layer,expert,proj)
    unique_rows = np.unique(ww,axis=0).shape[0]
    rows.append({'layer':layer,'expert':expert,'projection':proj,'shape':list(ww.shape),
                 'zero_elements':int(np.sum(ww==0)), 'elements':int(ww.size),
                 'all_zero_rows':int(np.sum(np.all(ww==0,axis=1))),
                 'all_zero_columns':int(np.sum(np.all(ww==0,axis=0))),
                 'unique_rows':int(unique_rows), 'provenance':provenance})
    print(json.dumps(rows[-1]),flush=True)
pathlib.Path(__file__).with_name('sparsity-followup-results.json').write_text(json.dumps({'scope':'Checkpoint-only static counts, five selected matrices; no inference or timing','rows':rows},indent=2)+'\n')
