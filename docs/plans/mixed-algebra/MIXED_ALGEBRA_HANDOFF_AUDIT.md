# Mixed-Algebra Handoff Audit

Date: 2026-09-29. Scope: the Omega mixed-algebra program (ADR 0019, MA-0 to MA-8) and the outside-model artifacts that fed it. Read-only audit; this file is the only change. Every row cites a file you can open. Where a claim could not be checked, it says so.

## 1. Pins

| Repo | Ref | Commit |
|---|---|---|
| aien-architecture | origin/main | `550872e` (Require qualification evidence before claiming R16 PASS, #61) |
| omega | origin/main | `f7f60dd` (Merge #81 feat/program-realize) |
| omega | origin/feat/mixed-algebra-gpu (unmerged, no PR) | `753adda` on top of `b41811f`, base `87938dc` |
| omega | feat/mixed-algebra-digital-v1 (local worktree `~/workspace/omega-ma-digital-v1`, not pushed) | `f7f60dd` (zero commits beyond main at audit time) |
| Outside artifacts | `~/.claude/jobs/c8884ded/tmp/` | `gemini-priorart.md` (200 lines), `grok-phase-hw.md` (163 lines), `gemini-brief.txt`, `grok-brief.txt` |

The digital closure gate (`MIXED_ALGEBRA_DIGITAL_V1`): PASS on omega `feat/mixed-algebra-digital-v1`, receipt `evidence/MIXED_ALGEBRA/digital_v1/04f0f9ab01fc55fcc94391fe5032b18f3ca8c039e00b9f4be66cfb05ec28ddc1.json`, omega PR #87 (https://github.com/aien-spark/omega/pull/87). Nothing in this audit depends on it.

## 2. Artifact classification

| Artifact | What it was asked | Classification | Reason | Evidence |
|---|---|---|---|---|
| Gemini prior-art survey (`gemini-priorart.md`) | 8-topic literature survey with a source for every claim, "unverified" instead of invention (`gemini-brief.txt`) | ACCEPT WITH CHANGES, RESEARCH ONLY | Landed after a citation check: 15 key citations checked, 7 VERIFIED, 7 WRONG DETAILS (fixed), 1 NOT FOUND (removed). Wrong: T-MAC authors/venue/speedup; RNSnet numbers (understated about 20x to 60x, wrong baseline); Res-DNN authors and venue invented; HERMES title/venue and misattributed 63.1 TOPS / 9.76 TOPS/W; Chumak 2015 is a review; Pedersoli TCSI 2018 not found. Unchecked text kept as leads, tagged **[unverified]**. It informs; it proves nothing about my hardware. | arch `docs/plans/mixed-algebra/research/PRIOR_ART.md` lines 8 to 12; merged in arch #58 (`e2bb8a8`) |
| Grok design note, as a document (`grok-phase-hw.md`) | Phase-domain Z3 experiment, 6 to 8 buyable boards, smallest first rig (`grok-brief.txt`) | ACCEPT WITH CHANGES | Landed with five corrections: a spliced summary paragraph repaired; error table was for one noisy phasor, an add is two (about 2 dB worse, Monte Carlo added); ADALM-PLUTO price wrong ($399.99 vs about $215 to $280); STEMlab price was the PRO tier; Pmod DA4 has 8 channels, not 2. The Monte Carlo program is outside the repo. | arch `docs/plans/mixed-algebra/research/PHASE_EXPERIMENT_AND_HARDWARE.md` lines 8 to 10 |
| Grok physical phase experiment (converters in the loop) | same | RESEARCH ONLY, physical run BLOCKED | No physical rig exists. Purchase is held behind three conditions (twin passes 9 x 1000; existing bench checked; claim is more than the group law). First rig named: ULX3S ECP5-85F $275 + $8 shipping, Pmod DA4 about $25 to $27, bias parts about $15, **total about $320 to $325**. Needs a purchase decision by Drake; no purchase has been proposed or approved in any committed file. | same file, lines 155 to 176 |
| Phase digital twin (omega#84, the Grok note's "$0 first step") | n/a (built in omega) | ACCEPT (merged), MODEL ONLY | `src/algebra/phase_twin.{c,h}`, `tests/algebra/test_phase_twin.c`, receipt `"overall": "PASS"`. The receipt itself says "No physical, speed, latency or energy claim". It is a simulation in C, not physical evidence. | omega `spec/mixed-algebra-phase-twin.md`; `evidence/MIXED_ALGEBRA/phase_twin_receipt.5d6ca45e...json`; merge `7350a61` |
| `~/workspace/plans/BROWNIAN_DISCOVERY_SPEC.md` (Grok) | Brownian / stochastic law discovery benchmark | OUT OF LANE | Header: "Brownian Discovery Benchmark, profile v1 ... evaluator-side specification". Owned by the live Brownian session. Content not evaluated here. | file header, lines 1 to 5 |
| `~/workspace/BROWNIAN_INTEGRATION_AUDIT.md` (Gemini) | Brownian benchmark integration map | OUT OF LANE | Header: "AIEN Brownian Discovery Benchmark: Integration Audit". Owned by the Brownian session. Content not evaluated here. | file header, lines 1 to 8 |

## 3. Integration gaps

### Already merged (omega main `f7f60dd`)
- MA-1 oracle: `src/algebra/oma_trit`, `oma_pack`, `oma_quant`, `oma_z3` (commit `6d517a4` is now an ancestor of main).
- MA-2 realizations of Omega-X (y = W.x, ternary W, int8 x, exact): registry `src/algebra/realize_common.h` lines 76 to 80 lists R1 plain/sdot/sdot_il/smmla, R2 bitplane, R2b LUT, R2c crumb, R3 sparse, R4 RNS, R5 dense5. Spec `spec/mixed-algebra-ma2.md`; receipts `evidence/MIXED_ALGEBRA/ma3_bench_run{1,2}.json`, `ma2_select_receipt.json`.
- Selector alignment (omega#82, `3a1ec94`): `oma_select` retired for new decisions; `src/turing/select.h` line 55 `turing.field.v1` is the live record layer, ranking by `turing_rank_min_cost`; records use `turing.decision.v1` (`src/turing/field.h` line 36).
- Phase twin, MA-8 step 0 (omega#84).
- ADR 0019 accepted plus Amendment 1 (arch #60, `13b4766`): lowest measured cost wins; a tie never changes the choice.

### Implemented but unmerged
- MA-6 GPU realizations, branch `feat/mixed-algebra-gpu` (`b41811f` encoder ops LOP3_LUT, POPC, IADD3_R3, LDG_E_OFF; `753adda` realizations + pre-registration). No PR open. `git ls-tree` shows only the three inherited MA-2 receipts under `evidence/MIXED_ALGEBRA/` and no GPU or MA-6 file anywhere under `evidence/`; no GPU chip receipt exists. `spec/mixed-algebra-ma6-gpu.md` section 8 "Results" is empty. GPU claims are pre-registration only.
- Digital closure gate, `feat/mixed-algebra-digital-v1`: branch exists, no commits yet beyond main.

### Research only
- PRIOR_ART.md and PHASE_EXPERIMENT_AND_HARDWARE.md (above). Theory rows in `MIXED_ALGEBRA_THEORY.md` marked PREDICTION or CONJECTURE (ADR 0019 section 11).

### Duplicated
- Two selectors: `src/algebra/oma_select.{c,h}` (RETIRED, kept only to reproduce `ma2_select_receipt.json`) and `src/turing/field_select.c` (`turing.field.v1`, live); plus `field_select_v0_retired.c`.
- Two realization tables: MA-6 spec section 2 declares a GPU table "separate ... not the CPU `oma_rz` registry".
- Label clash: files `ma3_bench_run*.json` carry an old "MA-3" work label but are stage MA-2 evidence (ADR 0019 section 9.1 records this).
- Three machine-identity shapes unreconciled: `CqCandidate.machine_id` u32, FORGE V2 32-byte id, OS-0010 `MachineId` (ADR 0019 section 12).

### Contradictory or stale
- ADR 0019 section 10 says MA-1 "exists on the omega worktree commit `6d517a4`, not on `main`". Stale: `6d517a4` is on omega main.
- ADR 0019 section 11 says `doctrine/ROADMAP.md:282` records R16 PASS. Stale: ROADMAP line 282 and `CURRENT_EXECUTION_PLAN.md` line 45 now both say IN PROGRESS (arch #59, #61). The conflict is resolved; the ADR text is not updated.

### Missing semantic types
- No Omega semantic id for Omega-X. Program identity v2 is a chain of unary scalar steps (`src/omega_program.h` lines 38 to 55, ops ADD SUB MUL AND OR); it cannot name a matvec. MA-2 and MA-6 cite a PROVISIONAL Turing `contract_digest` (`75772afe...`) instead of minting one.

### Missing realization types
- No GPU realization on main (MA-6 unmerged). Omega's SASS path has no INT8, FP8 or FP4 encoders (ADR 0019 section 12).
- No physical or external-Machine realization (MA-8 beyond step 0). FORGE v1 cannot execute kernels (ADR 0019 section 12).
- FORGE V2 digital fallback counts only DIGITAL_CPU and DIGITAL_GPU, so an exact FPGA realization would not qualify as fallback.

### Missing verifier support
- V2 ignores the realization: `src/omega_verify.c` line 175 `(void)real;`. V3 to V5 are stubs. Evidence tiers (ADR section 8) live in receipts, not in code.
- `rx_contract` is exact-only; bounded kinds and per-domain error units (MA-3) are not expressible (ADR 0019 section 12).

### Missing benchmark support
- `rx_costmodel` covers one operation: `src/runtime/rx_costmodel.h` line 37 `RX_CM_OPS 1u`. MA-2 selection is a test-side nearest-cell lookup; `ma2_select_receipt.json` `not_claimed` lists "integration with rx_costmodel or the resident omega.select reaction" and "multi-core or GPU realizations".

### Missing evidence fields
- Note: energy IS recorded in the MA-2 bench receipts. `ma3_bench_run1.json` has an `"energy"` block (hwmon meter, whole Cortex-X925 cluster, "indicative only on a shared machine").
- What is missing: per-realization attributed energy, energy as a selection input (`ma2_select_receipt.json` `not_claimed` includes "energy-based selection"), any energy in the phase twin receipt (none claimed), and any MA-6 GPU energy (no runs).

### Missing cost fields
- ADR 0019 section 9.1 names seven cost terms: bytes moved, latency, energy, conversion, verification, calibration, link. The `turing.decision.v1` record carries one per-candidate time cost `cost_ps[]` plus `weight_bytes` and `working_set_bytes` (`src/turing/field.h` lines 91, 134). No energy, verification, calibration or link term. Conversion is folded into time only in per-call mode (pack + run).

### Selection logic
- Live: `turing.field.v1` with `turing_rank_min_cost` (matches Amendment 1). Retired: `oma_select` tie rule, `turing.field.v0`. No algebra classifier (MA-7) exists; ADR says it may only propose, never pick.

### Missing tests
- Make targets exist on main: `test-algebra`, `test-algebra-asan`, `bench-mixed-algebra`, `test-phase-twin` (Makefile lines 913, 916, 983, 1029). No workflow reference to them was found by grep of `.github` on main.
- No test exercises a realization through the verifier (blocked by `(void)real`). No GPU test on main. No energy-attribution test for MA receipts (omega#86 adds Turing energy checks, not MA ones).

### Open omega PRs touching this area
- #86 "Finish Turing energy attribution safety boundaries" (`fix/turing-energy-closeout`): Turing Yield energy records, not MA receipts.
- #32 "OMEGA-NUMERIC-0 / Blackwell FP32 SIMT" (`feat/forge-v1-numeric`): GPU numeric substrate; related to MA-6 encoders, not merged.

## 4. Negative findings preserved

| Finding | Source |
|---|---|
| R4 RNS loses everywhere amortized: 1.4x (DRAM-bound) to 90x (m = 1) slower than int8 SDOT | omega `spec/mixed-algebra-ma2.md` lines 212 to 215 |
| R3 sparse never wins on the grid, 1.5x to 1.7x behind SDOT at m = 1 even at 90% zeros | same, "Negative results" |
| R2b LUT (T-MAC style) correct but loses to bitplane and crumb; m = 1 worst (58x R1) | same, "Negative results" |
| Ternary wins only when DRAM-bound (m = 4096): R2c crumb 2.2x to 3.0x; binary wins when weights are L1/L2-resident; in pack-per-call mode no packed form beats a copy | same, lines 188 to 208 |
| Incumbent / digital-reference tie rule failed the pre-registered TURING kill test: 3.58% mean, 25.51% max regret vs 0.01% / 0.07% for min-cost, 8 decisions, in sample | ADR 0019 section 9.1 and Amendment 1; omega `docs/turing/TURING_W0_PROPOSAL.md` K.4, K.6, K.7 |
| Z3 x Z3 multiply with two unknown operands is not realizable as a phasor operation ("Two unknown operands: **not realizable in this model.**" `w^(ab)` is exponentiation, not bilinear). Multiply by a known constant is realized. | omega `spec/mixed-algebra-phase-twin.md` lines 151 to 161 |
| 7 of 15 Gemini citations had wrong details, 1 did not exist | arch PRIOR_ART.md line 8 |
| A 5 GSPS converter does not change `(1+2) mod 3`: expensive RF boards add nothing to the group-law claim | arch PHASE_EXPERIMENT_AND_HARDWARE.md line 163 |

## 5. Physical and analog blockers remaining

1. **Purchase decision (Drake).** No physical phase rig. Smallest named rig about $320 to $325 (ULX3S 85F + Pmod DA4 + parts). Not proposed for purchase in any committed file.
2. **Purchase hold conditions** (PHASE doc line 160). Condition 1 (twin passes 9 x 1000) appears met: the phase twin spec runs all 9 input pairs x 1000 per gate (lines 102 to 108) and the receipt says overall PASS. No committed file records the hold as released. Condition 2 (check existing bench for any 2-channel generator + capture) is not recorded as done.
3. **Tooling unknowns** still marked **verify** in the source: aarch64 build of yosys/nextpnr-ecp5, ULX3S per-channel ADC rate, STEMlab base price.
4. **FORGE:** v1 cannot execute kernels; V2 fallback excludes FPGA (ADR 0019 section 12). An FPGA realization would have no FORGE path today.
5. **R16 runtime-edit freeze** still IN PROGRESS, so MA-3 and MA-5 `rx_*` changes remain blocked (ADR 0019 section 11; ROADMAP line 282).
6. **Hybrid decode-then-select** for Z3 multiply is digital, not claimed as phase-domain.
