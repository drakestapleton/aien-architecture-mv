# Making "the necessary work is the limiting factor" possible: feasibility research

Date: 2026-10-18. Author: Claude Fable 5.1 (orchestrator job 1b09638a), working alone; no worker agents.
Subject: the plan Drake handed over on 2026-10-18, "AIEN: Make the Necessary Work the Limiting Factor"
(copied verbatim to [docs/plans/necessary-work/AIEN_Physical_Limits_Project_Plan.md](../plans/necessary-work/AIEN_Physical_Limits_Project_Plan.md),
47,779 bytes, 16 sections, experiments E01 to E20, phases 0 to 5, source anchors G1 to G10).
Question answered: can AIEN run this program, what already exists, what collides with standing rules, what must be built, and in which order.
Scope: read-only. No GB10 run, no code change. Repository facts were read from GitHub main branches, not from local checkouts
(the local `omega` and `aien-sovereign-core` clones point at the old organisation and sit on feature branches).

Tags: PROVEN = a primary source says it (URL plus file, line or section). INFERRED = reasoning from proven facts.
UNVERIFIED = not established, with the check that would settle it. Arithmetic cites `aien-calc` receipts (calc:id) where one exists.

## In plain words (read this first)

The plan says: before making the chip faster, find out which work is unnecessary and delete it, prove that what remains is
necessary, run that remainder as close to the hardware's limit as the hardware allows, and never call a slow result "physics"
without a proof. It is a research programme with twenty experiments, six promotion gates and an append-only evidence ledger.

Verdict: **it is possible, and most of its foundations already exist.** Every one of the sixteen files the plan cites exists on
today's main branches, and every headline number in it matches the evidence file it points at. Nothing in the plan needs new
hardware, Python, CUDA or an outside service. Five things in it collide with Drake's standing rules (units, the yardstick, time
estimates, outside comparisons, roles); each has a fix below, and the fixes are written into the GitHub issues. Six pieces of
apparatus do not exist yet and must be built before their experiments can run: a clock-calibration check for the native timers,
a hardware reference atlas, a translation-validation slice, the evidence-ledger fields, a checked work-reduction library and a
frozen objective suite. The first experiments (E01, E02, E04) need only the CPU and can start beside the current critical path
without touching the chip.

## 1. Ground truth: every anchor checked against GitHub main (2026-10-18)

| Anchor | File (repository) | On main today | Number in the plan | What the file says | Tag |
|---|---|---|---|---|---|
| G1 | `src/omega_gpu_decode_graph.c`, `src/omega_gpu_cmdlist.c`, `src/omega_gpu_platform_linux.c` (omega-mv) | yes | none | native decode command lists exist | PROVEN [S1] |
| G2 | `docs/inference/evidence/own30b-L2-20261013/graph-on-stamps/stdout` (sovereign-core-mv) | yes | 24.48 ms span, 48.6 us record | line 41: `TIMELINE span 24483.5 us/step`; line 27: `record 48.6 us` | PROVEN [S2] |
| G3 | `docs/inference/evidence/own30b-requal-main-20261015/NOTES.md` (sovereign-core-mv) | yes | TTFT 2,048 tokens 32.1 to 32.2 s off, 0.85 to 0.88 s on; graph-on 39.5 to 42.6 tok/s | line 21: `32.2 / 0.88 s, 32.1 / 0.85 s`; line 25: `42.6 / 39.5 / 40.8 / 40.1 tok/s` | PROVEN [S3] |
| G4 | `docs/inference/evidence/draft-verify-20261012T1500Z/README.md` (sovereign-core-mv) | yes | B=2: 89.731 s to 57.358 s, identical output; larger blocks diverged | line 18: `B=2 ... 57358 ... 0.64 ... yes`; lines 19 to 20: B=4 and B=8 diverge from index 764 | PROVEN, see section 4 [S4] |
| G5 | `evidence/OWN30B-REQUAL-MAIN-710d438c-20261015/gates/l2d_prefetch.out` (omega-mv) | yes | cached 3.95 to 3.98 ms vs prefetch 4.06 to 4.08 ms | per-kind timelines for cached, cached-prefetch, uncached-prefetch; red control fails as intended; gate PASS | PROVEN (sums not re-added by me) [S5] |
| G6 | `src/runtime/rx_plan.h`, `rx_plan.c` (omega-mv) | yes | candidate/verified/stale, capacity, cost counters | lines 14 to 17: CANDIDATE, VERIFIED, STALE; line 45: `PL_MAX_TEMPLATES 32`; line 110: applicability axes | PROVEN [S6] |
| G7 | `src/runtime/rx_projection.h` (omega-mv) | yes | none | typed state projection exists; `rx_projection.c` and `tests/runtime/rx_plan_reuse.c` also exist | PROVEN [S7] |
| G8 | `spec/one-layer-receipts.md`, `src/checker2/c2_lrat.c` (omega-mv) | yes | class 1 binds bytes by hash, no translation validation; class 2 = LRAT no-trap | line 68: "bound by hash only; it is **not** translation-validated"; line 175: property `no-trap-except-requires` | PROVEN [S8] |
| G9 | `README.md`, `spec/omega-language-v0.md` (omega-mv); `CONTEXT.md` (sovereign-core-mv) | yes | none | present; wording "implemented / historical / qualified" not re-read by me | PROVEN exists, wording UNVERIFIED [S9] |
| G10 | `src/omega_blackwell_codegen_moe2.h` (omega-mv) | yes | none | FP8 load-pipelining variant exists | PROVEN exists [S10] |

Pins. omega-mv main is `f4a9849fb127f8d2d664dfc56890752ad180c507` (2026-10-17), identical to the plan's pin [S11].
aien-sovereign-core-mv main is `1db20d44` (2026-10-18), one commit after the plan's pin `e6852de8`; that commit is
"Spark merges one PR at a time per repo so main stops ending up with stale crumbs (#657)", a CI change that moves no evidence [S12].
The "architecture authority" the plan could not retrieve is `aien-dev/aien-architecture-mv` (the unsuffixed name redirects there):
`PLAN_AUTHORITY.md`, `CURRENT_EXECUTION_PLAN.md`, `doctrine/ROADMAP.md`, `doctrine/ARCHITECTURE.md` [S13].

No GitHub issue for this programme existed before this note (`gh search issues --owner aien-dev "physical limits"`: three unrelated hits) [S14].

## 2. Where the plan collides with Drake's standing rules, and the fix

| # | The plan says | The standing rule | Fix carried into the issues |
|---|---|---|---|
| 1 | Results in tokens/s, TTFT seconds, bytes | Measure in SI units: seconds, joules, watts per accepted unit of work, next to a physical bound with its derivation; tokens and bytes are supporting facts only (Drake 2026-10-14) [S15] | Every experiment reports s and J per accepted objective and W, with the bound beside it. Token counts stay in the raw receipts. |
| 2 | Primary unit = "correctly completed objective" | Turing yield T (held-out bits gained) and T/J is the guiding star; the model asks "how do I get more Turing today?" (Drake 2026-10-16) [S16] | Track C's primary figure is T and T/J against my own previous run; "correctly completed objective" stays as the acceptance gate underneath it. The TY-x measurement machinery is not built yet, so until it is, the gate figure is reported alone and labelled. |
| 3 | 12-week campaign, "first ten working days", 50/25/25 effort split | No estimates without a receipt (Drake 2026-10-16) [S17] | Keep the order, drop the durations. Phases exit by gates, not by weeks. The ten-day table becomes ten ordered work units. |
| 4 | Literature R1 to R7 and Nsight D1 as grounding | No outside comparisons; outside tools are research or a comparison point, never the plan (Drake 2026-10-16) [S18] | Papers may motivate an experiment; no published speedup appears in any result. Nsight is not used on the native path; the native chip timestamps are the instrument (the plan itself says this). |
| 5 | Six named roles, author is not sole reviewer | One orchestrator does the work; models by job: Fable for proofs and deep analysis, Opus for everyday building, Astra for targeted bugs, Grok for mathematical verification, Haiku for watching runs (Drake 2026-10-13/18) [S19] | Role codes map to models, not people. MATH and REVIEW = Fable or Grok; OMEGA, GPU, AGENT, EXP = Opus with Astra on hard bugs. "Author is not sole reviewer" is met by a different model reviewing. |
| 6 | "No arbitrary percentage is called the physical limit" | No percent targets, infinite game: report against yesterday plus distance to the ceiling, keep going (Drake 2026-10-16) [S20] | Compatible. Kept as written. |
| 7 | "Promote through the project's normal review and candidate process" | Spark is the only test judge; the PR desk chat alone opens and merges PRs; `quietlock check` before any GPU run; chip runs are never killed; no Python; no CUDA [S21] | Each issue names its test command and the evidence path; results land through the desk. |
| 8 | A new programme plan | `PLAN_AUTHORITY.md`: finite workstream plans live under `docs/plans/<name>/`, marked NOT A MASTER PLAN; no file may call itself the master plan [S13] | Folder `docs/plans/necessary-work/`. No new roadmap milestone. It feeds `CURRENT_EXECUTION_PLAN.md` Phase E (E1 numerical closure, E2 M20 tensor) and Phase H3 (the optimisation loop). |

## 3. What already exists for each experiment, and the gap

| Exp. | Exists today (PROVEN unless tagged) | Gap to close before the experiment can run | First cut |
|---|---|---|---|
| E01 trace objectives | Odysseus request capture flag noted in the TTFT floor design [S22]; sovereign-core serving spine | No objective-level cost ledger | Trace ten real objectives, count model calls and repeated work; no speedup claim |
| E02 CPU checker vs model pass | `checker2` with LRAT class 2 [S8]; `aien-calc` exact arithmetic with receipts | No per-domain cost comparison; no wrong-witness corpus | Three domains: bit-vector kernels, finite constraints, arithmetic witnesses |
| E03 plan reuse | `rx_plan` with CANDIDATE/VERIFIED/STALE and `tests/runtime/rx_plan_reuse.c` [S6][S7] | No cold/warm/new-binding/changed-precondition campaign on held-out cases | Run the four partitions against the existing test as baseline |
| E04 checked reductions | `spec/canonical-encoding.md`, `src/omega_canonical.c` [S23] (canonical identity, not equivalence) | No library of proven rewrites with finite-width semantics | Derive 3 to 5 hot pure operations by hand; exhaustive small-domain check |
| E05 translation validation | Receipt class 1 binds executable bytes by hash only [S8]; `src/omega_validate.c` exists, purpose UNVERIFIED [S24] | The IR-to-machine-code relation is unproven for any subset | Corrupt native bytes under a valid IR; build the smallest refusing validator for one instruction subset |
| E06 bounded rewrite search | Nothing found for equality saturation in omega-mv (tree grep: no egraph, no saturation) [S25] | Whole mechanism; outside crates are research only, so a native version would be built if E04 shows the need | Run after E04 proves rewrites pay |
| E07 typed projections | `rx_projection.h/.c` [S7] | No sufficiency test with planted facts | Compare full state, declared projection, projection plus recall |
| E08 incremental verification | Receipt dependency resolution open in v1 [S8] | Invalidation rules for supported structures | One-dependency-at-a-time mutants |
| E09 timer calibration | Native chip timestamps (`chip_ns`, `TIMELINE`) in the graph-on stamps [S2]; the omega `calibration/` folder is the Turing coder calibration, not GPU clocks [S26] | No host-to-device clock calibration, no observer-overhead measurement, no null-kernel control | Null kernels, dependent and independent chains, stamps on and off, known sleeps |
| E10 hardware atlas | 2026-10-13 investigation: measured stream 205 to 236 GB/s against the 273 GB/s specification; decode floor 3.3 GB per step at 236 GB/s = 14 ms (calc:498ec812) [S27][S28] | Not a versioned atlas with conditions and uncertainty; gather, read/write and dependency cases missing | Re-measure with production memory modes and record conditions |
| E11 FP8 load scheduling | `omega_blackwell_codegen_moe2.h` variant [S10] | Isolation of load, conversion and reduction | Per-shape sweep, operation order preserved |
| E12 barriers and traffic | GB10 completion flag must be uncached (lesson 2026-10-02) [S29] | Qualified memory/barrier contract | Stale-data mutants on the existing paths |
| E13 fusion | combine+norm fusion exists (plan's baseline) | End-to-end measurement with registers | gate/up+SwiGLU candidate vs chain |
| E14 draft verification | B=2 identical, B=4/B=8 diverge at a numerical tie (coin flip, not a fault); preregistered rule NOT MET narrowly; one run per setting [S4] | Reproduction; a contract for ties; held-out workloads | Reproduce B=2 three times, then decide the tie contract before any larger block |
| E15 TTFT | Requalified 2,048-token TTFT 0.85 to 0.88 s [S3]; `own30b_ttft.rs` and the PKV scripts [S30]; PREFILL-0/3/4 specs [S31]; TTFT floor design [S22] | Cold/warm/prefix-hit matrix not run as one campaign | Fold into the PREFILL-E2E critical path rather than a parallel lane |
| E16 compiled tool workflow | `rx_plan` arrange [S7] | One pure read-only workflow compiled into checked transitions | Pick one Odysseus read-only query |
| E17 compression | DUAL cost records `docs/dual/` [S32] | Lossless-first candidates with entropy controls | After E10 atlas |
| E18 superoptimisation | OSC code generation [S10] | Only if E04/E06 reuse economics justify it | Last |
| E19 out-of-sample prediction | None as a standing gate | Recurring gate on every explanation | Attach to every retained kernel change |
| E20 release dossier | Omega `evidence/<CAMPAIGN>/README.md` convention (223 campaign folders) [S33] | Frozen held-out objective suite; sustained thermal run | Only after both tracks have results |

## 4. Where the plan reads the evidence differently from the evidence

The draft-verification record is the one place to correct before work starts. The plan says "larger blocks diverged" and asks
to "resolve arithmetic-path differences". The evidence file says the B=4 and B=8 divergence is a tie at output index 764 where two
candidates sit 0.008 apart on a scale of 29, and "a coin flip that moves with any change of numerical path ... not a fault"; the
run's own preregistered rule (identical ids for every B and best-B at or under 0.6x) was "NOT MET, narrowly on both axes", with
one run per setting on a development harness [S4]. Consequence for E14: the first decision is a tie contract (what counts as
identical when the plain path itself is a coin flip), not a kernel fix. The plan's Track B wording already separates
"deterministic token sequence" from "target sampling distribution"; E14 must pick one before the block size is raised.

The plan's 82 tokens/s weight-streaming estimate uses the 273 GB/s specification. The 2026-10-13 investigation measured
205 to 236 GB/s on this machine [S27]; in SI terms the single-stream decode floor at the measured figure is 14 ms per step for
3.3 GB of active weights (calc:498ec812) [S28]. The atlas (E10) replaces the specification figure with measured, conditioned ones.

## 5. How to run it under my rules

1. **Folder.** `docs/plans/necessary-work/` holds the plan verbatim and a README marked NOT A MASTER PLAN. Sequencing stays in
   `CURRENT_EXECUTION_PLAN.md`; no roadmap row changes [S13].
2. **Issues.** One epic plus one issue per experiment and one for Phase 0, all in `aien-dev/aien-architecture-mv`, labelled
   `needs-triage`, each carrying hypothesis, controls, deliverable, model assignment, gates, SI-unit reporting line and the
   evidence path. The issue numbers are listed in the folder README once filed.
3. **Order.** Phase 0 first (contracts, pins, three CPU objective families, apparatus check). Then E01, E02, E04 on the CPU, which
   need no chip slot and can run beside the PREFILL-E2E critical path. E09 and E10 take the first quiet chip slot (`quietlock check`).
   E05 to E08 and E11 to E13 follow their gates. E14 to E17 need a sound inference contract first. E18 to E20 close the campaign.
   E15 is not a separate lane: it folds into PREFILL-E2E, which already owns TTFT.
4. **Evidence.** Omega campaigns under `evidence/<CAMPAIGN>/` with a README; sovereign-core campaigns under
   `docs/inference/evidence/<campaign>/`. The section-10 ledger fields become the README template, with `claim_strength` added
   as its own line: proven_in_scope, measured, inferred, unresolved.
5. **Reporting.** Each result: seconds and joules per accepted objective, watts, the bound beside it with derivation and calc id,
   the same figure from my previous run, and the distance to the ceiling. Nothing else is a headline [S15][S20].
6. **Review.** A different model reviews than the one that built; Fable or Grok for proofs and bounds [S19]. Results land through
   the PR desk; Spark judges every test [S21].
7. **Negative results stay.** The prefetch negative [S5] stays on the ledger; a reopening must name the changed premise, as the plan says.

What Drake decides: nothing is blocked on him. The only open choice is whether this programme shares the Spark with
PREFILL-E2E now or waits; the recommended path above avoids the conflict by starting on the CPU.

## 6. Unverified items and the check that settles each

- The purpose of `src/omega_validate.c` in omega-mv: read the file header (one GitHub read).
- Whether any host-to-device clock calibration exists anywhere in omega-mv: a grep for `clock_gettime` next to `chip_ns` in `src/`.
- Nsight compatibility with the native submission path: the plan marks it unverified; it still is. Not needed if E09 uses native stamps.
- The 20.35 ms projection share in G2 and the 3.95 to 4.08 ms sums in G5: I did not re-add the per-kind lines; the headline span and record figures were checked.
- The "implemented / historical / qualified" wording in the omega-mv README (G9): file exists; wording not re-read.
- Energy: no on-board joule measurement is proven for the inference path. The 2026-10-14 rule allows UNMEASURED with the external
  instrument named (a calibrated wall power meter) [S15]. Every J figure in this programme stays UNMEASURED until that exists.

## 7. Sources

- S1 https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/src/omega_gpu_decode_graph.c and `src/omega_gpu_cmdlist.c`, `src/omega_gpu_platform_linux.c` (presence checked in the recursive tree of main, 16,078 paths).
- S2 https://github.com/aien-dev/aien-sovereign-core-mv/blob/e6852de85dfe503347d37ed2438d1ce6f1ac8c3a/docs/inference/evidence/own30b-L2-20261013/graph-on-stamps/stdout lines 27 and 41.
- S3 https://github.com/aien-dev/aien-sovereign-core-mv/blob/e6852de85dfe503347d37ed2438d1ce6f1ac8c3a/docs/inference/evidence/own30b-requal-main-20261015/NOTES.md lines 20, 21, 25.
- S4 https://github.com/aien-dev/aien-sovereign-core-mv/blob/e6852de85dfe503347d37ed2438d1ce6f1ac8c3a/docs/inference/evidence/draft-verify-20261012T1500Z/README.md lines 15 to 20 and 24 to 36.
- S5 https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/evidence/OWN30B-REQUAL-MAIN-710d438c-20261015/gates/l2d_prefetch.out lines 3, 7, 9, 11, 13.
- S6 https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/src/runtime/rx_plan.h lines 2 to 23, 45, 105, 110 to 122.
- S7 omega-mv main tree: `src/runtime/rx_projection.h`, `rx_projection.c`, `rx_plan_arrange.h/.c`, `tests/runtime/rx_plan_reuse.c`.
- S8 https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/spec/one-layer-receipts.md lines 68, 69, 173 to 176; `src/checker2/c2_lrat.c` present.
- S9 omega-mv main tree: `README.md`, `spec/omega-language-v0.md`; sovereign-core-mv main tree: `CONTEXT.md`.
- S10 omega-mv main tree: `src/omega_blackwell_codegen_moe2.h`.
- S11 `gh api repos/aien-dev/omega-mv/branches/main` on 2026-10-18: `f4a9849f...` committed 2026-10-17T00:21:02Z; compare pin...main: identical.
- S12 `gh api repos/aien-dev/aien-sovereign-core-mv/compare/e6852de8...main`: ahead by 1, commit `1db20d4` "#657".
- S13 https://github.com/aien-dev/aien-architecture-mv/blob/main/PLAN_AUTHORITY.md ("A finite workstream plan under docs/plans/ is allowed only when its scope is explicit and it is marked NOT A MASTER PLAN"); `CURRENT_EXECUTION_PLAN.md` sections 8 (Phase E) and 11 (Phase H).
- S14 `gh search issues --owner aien-dev "physical limits"` on 2026-10-18: aien-architecture-mv#231, aienos-mv#396, aienos-mv#383, none about this programme.
- S15 Mind map note `2026-10-14-measure-in-physical-units-chase-physical-limits` (Drake verbatim, 2026-10-14).
- S16 Mind map project note `turing-yield-program` (Drake 2026-09-29 brief; 2026-10-16 "guiding star").
- S17 `~/.claude/CLAUDE.md` section "No estimates without a receipt (Drake, 2026-10-16)".
- S18 Memory `no-outside-comparisons` (Drake 2026-10-16) and `~/.claude/CLAUDE.md` "Build our own, close to the metal (Drake, 2026-10-16)".
- S19 `~/.claude/CLAUDE.md` "How work is run" (Drake 2026-10-13 model rule; 2026-10-18 main-agent rule).
- S20 Memory `no-percent-targets-infinite-game` (Drake 2026-10-16).
- S21 Memories `spark-pipeline-is-the-test-judge`, `merge-control-3649dd`, `quietlock-check-before-scripts`, `gpu-chip-test-no-kill`, `no-python-repos`, `decision-leave-max`; PR-desk message of 2026-10-18 18:55Z.
- S22 `~/handoffs/2026-10-13-ttft-physical-floor-design.md` (physics receipts calc:f31833c4, calc:022c9279, calc:498ec812; design T1 to T4).
- S23 omega-mv main tree: `spec/canonical-encoding.md`, `src/omega_canonical.c`.
- S24 omega-mv main tree: `src/omega_validate.c`, `src/omega_validate.h` (header comment not read).
- S25 omega-mv main tree grep for `egraph|saturat|rewrite` outside `evidence/`: only atemporal evaluator cases and canonical encoding.
- S26 https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/calibration/docs/CODER_SPEC.md ("EXP-001 coder specification", Turing coders A and B).
- S27 `~/workspace/investigations/2026-10-13-physical-limits-inference/REPORT.md` (measured stream 205 to 236 GB/s; ranked levers; calc:7af88980, calc:dc44d761).
- S28 calc:498ec812 (3.3 GB at 236 GB/s = 14 ms), recorded in S22.
- S29 Memory `gb10-completion-flag-uncached` (2026-10-02 root cause of E1 stalls).
- S30 sovereign-core-mv main tree: `crates/aien-inference-abi/src/bin/own30b_ttft.rs`, `scripts/own30b-pkv-*.sh`.
- S31 `docs/plans/prefill/PREFILL-0-SPEC.md`, `PREFILL-3-SPEC.md`, `PREFILL-4-SPEC.md` in this repository.
- S32 omega-mv main tree: `docs/dual/DUAL_RECORDS.md`, `docs/dual/APPLICABILITY_EXPERIMENT.md`, `mk/dual.mk`.
- S33 omega-mv main tree: 223 top-level folders under `evidence/`, each with a README (sampled: `evidence/CAND2-PREP-PATHFIX-20261005/README.md`).
- S34 The plan's own source register (section 16): G1 to G10, R1 to R7, D1, D2, H1; its research workspace link is an outside tool and is not relied on here.
