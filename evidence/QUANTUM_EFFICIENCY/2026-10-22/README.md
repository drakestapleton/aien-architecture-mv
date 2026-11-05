# Quantum ideas for AIEN: what can actually save work

**Research snapshot: 2026-10-22. Tracking: [aien-architecture-mv#297](https://github.com/aien-dev/aien-architecture-mv/issues/297), L581. NOT A MASTER PLAN.**

## Bottom line

**Yes: the mathematics behind superposition offers useful engineering ideas. The strongest candidates on this hardware are better representations, removal of provably redundant work, and reuse of validated results. Simulating a quantum state is not a shortcut to quantum hardware.**

This investigation produced new static evidence from the actual FP8 checkpoint, not an inference speedup. One inspected expert contains matching all-zero channels in its gate, up and down projections. A structured rotation reduced toy 4-bit weight error on three preselected matrices. Conversely, those matrices do not support a blanket aggressive low-rank replacement. No production code, serving configuration, model or hardware was changed.

## What was actually examined

- Inventoried **11 repositories** and saved immutable refs in `repository-pins.json`: Omega, CUDApp, FORGE's current physics repository, sovereign-core, Aienux, Interplane, architecture, training, rig, Allen and AEGIS.
- Focused source reads covered the serving expert uploader, GPU GDN/graph path, compiler search, Store I/O, crypto and protocol/security boundaries. Training, Allen and rig coverage included declared implementation state, not every source file. Prior efficiency reports and live ledger ownership were reconciled.
- Surveyed **17 mechanism families** in the appended matrix. This is a broad map of computationally relevant mechanisms, not an exhaustive catalog of every named quantum state.
- Ran Wolfram algebra and resource checks. Ran CPU-only representation probes on three fixed checkpoint matrices, a five-matrix zero-structure follow-up, and independent-library FP8 decoding controls.
- Did **not** scan the whole checkpoint, run generation or perplexity tests, measure latency/joules, exercise quantum hardware, or audit every line of the project. Architecture intent, main-branch source and deployed artifacts remain separate evidence categories.

## 1. First priority: stop storing and moving known zeros

**Observed:** layer 0, expert 0 has 280 all-zero gate rows, 280 matching all-zero up rows, and 280 matching all-zero down columns. There are 512 channels in this expert. A byte-only second method confirmed that the zero-channel indices match across all three projections, without relying on the floating-point decoder.

Wolfram calculates that these channels account for **54.6875% of this expert's three FP8 weight payloads**, or **1,720,320 of 3,145,728 bytes**, before scale, index, alignment and layout overhead. This is neither a whole-model percentage nor a runtime speedup. The other two originally selected matrices have no fully zero rows or columns.

The inspected uploader (`sc-q36-batch@f0230a59`, `crates/aien-inference-abi/src/qwen38_omega/moe.rs:1-11,69-87`) describes fixed-size dense FP8 storage for 257 experts and appends their full weight bytes. That establishes a concrete place to investigate, not proof that every current deployment lacks another optimization.

**Recommended experiment:** start with lossless storage/transport compression and exact reconstruction of the original bytes/scales. Then, separately, test a sparse execution representation. Audit the whole checkpoint by streaming, record weighted routing frequency, and count bytes actually fetched. Preserve original scale-block membership and reduction order. NaNs, infinities, signed zero, bias terms and overflow mean that dropping a mathematically zero term is not automatically bit-identical floating-point execution.

**Gate:** original-byte reconstruction first; unchanged reference states/logits/tokens and intended negative controls for execution; actual same-model end-to-end latency and energy next. Reject a scheme whose index handling, gather traffic or decompression costs more than it saves. This finding is structural redundancy, not evidence of quantum behavior or naturally low entanglement.

Evidence: `sparsity-followup-results.json`, `zero-support-byte-confirm.json`, `weight-probe-results.json`.

## 2. Second priority: rotate before quantizing

For an orthogonal matrix Q, real-arithmetic linear algebra gives:

`W x = (W Q^T) (Q x)`.

The coordinates change, but the unquantized linear map does not. A good rotation can distribute outliers so that low-bit quantization represents the matrix more accurately. QuaRot and QuIP provide relevant classical precedents; their published model/implementation results are not AIEN performance receipts.[7][8]

The throwaway experiment used a **128-wide normalized Hadamard transform**, followed by symmetric INT4 rounding to [-7,7], one max-absolute scale per 128 weights, and inverse transformation. It compared reconstruction error against the existing FP8 checkpoint decoded to float64. It is **not** NVFP4, GPTQ, the full QuaRot/QuIP algorithm, or a trained rotation.

| Layer / expert / projection | Plain toy INT4 weight error | Rotated toy INT4 weight error | Relative error reduction | Rank-64 weight error |
|---|---:|---:|---:|---:|
| 0 / 0 / gate | 13.835% | 11.681% | 15.57% | 60.86% |
| 20 / 128 / up | 11.992% | 11.723% | 2.24% | 85.61% |
| 39 / 255 / down | 12.973% | 11.706% | 9.77% | 77.71% |

All error entries use `||W_approx - W||_F / ||W||_F`. Selection was fixed first/middle/last, not random or representative. No confidence interval or whole-model generalization follows from three matrices. Weight error does not measure generated-answer quality.

**Recommended experiment:** compare unrotated versus structured rotation at the same deployed bit budget, including scale metadata, activation transforms, packing and kernel cost. Use real activation calibration and held-out teacher-forced logits/NLL, then the existing shared model qualification path. Keep this explicitly approximate and separate from exact-token lanes. Transform placement must be derived around each nonlinear boundary; a rotation generally does **not** commute through SiLU or gating. Wolfram verified a simple nonlinear counterexample.

Potential benefit: fewer memory bytes for a fixed quality target. Unmeasured: model quality, end-to-end speed and joules. Rotations can also destroy existing sparsity, so test sparse and rotated representations separately before combining them.

## 3. Entanglement-inspired factorization: conditional, not a blanket win

Schmidt decomposition and tensor networks motivate storing factorizations rather than every tensor entry. Efficient classical simulation is possible in restricted-entanglement regimes; that does not imply a trained expert matrix has an economical low-rank approximation.[1]

For a 2048-by-512 matrix, a rank-r factorization stores `r*(2048+512)` coefficients. Wolfram's equal-precision payload break-even is integer rank 1–409. **BF16 factors versus the existing dense FP8 payload only win below rank 205**, before metadata and execution costs. Rank 64 would cut ideal weight payload by 68.75%, but the observed rank-64 weight errors are in the table above.

The first sampled matrix's numerical rank is only 232 because it has 280 zero rows. Treating that as evidence for useful approximate low rank would miss the simpler exact structure. The middle and final selections have numerical rank 512.

**Decision:** do not recommend a blanket rank-64 rewrite from these results. Test tensor-train/tree factorizations, shared expert subspaces or low-rank-plus-residual only on blocks with a favorable measured spectrum and activation-weighted error. Include factor loads, intermediate writes, contraction ordering and fitting cost. A small weight-error proxy alone cannot qualify the model.

## 4. Project-wide applications and existing ownership

The engineering interpretation is usually “eliminate repeated information or work,” not “run all alternatives at once.”

| Area | Useful mechanism / next discrimination | Current disposition |
|---|---|---|
| Omega search / AIEN_0 | Symmetry-aware canonicalization and reuse; learn candidate order while keeping verification outside the model. Compare solved tasks at equal verifier budget, not just fewer expansions. | Existing L049/L303. `cl_search.c:82-95,241-250,287-295` hashes outputs on examples/probes and prunes matches. **Finite-probe equality is not proof of universal semantic equivalence.** Do not label that pruning exact. L517 already covers related exploration diagnostics. |
| CUDApp / inference | Fuse legal transforms, keep recurrence state local, reuse expert weights across rows, and evaluate zero-aware layouts. | Inspect canonical module ownership before patching historical Omega copies. Existing prefill L403/L369 and serving L354; no duplicate kernel worker. GDN already has explicit reuse/fusion work, not an untouched discovery. |
| Output head / speculative work | Cheap screening plus a certified bound, then exact recheck of survivors; verify multiple candidate tokens together when acceptance justifies the work. | Exact-head L314 and chunked work L369 already exist. They are classical rejection/filtering methods, not Grover search. This audit does not remeasure their historical claims. |
| State / KV / precision | Preserve needed information with fewer reads/writes; batch updates where mathematically valid. | L313 exists, but its ledger explicitly corrects an earlier train PASS: BF16 state was OFF, so that train did not qualify the BF16 arm. Do not promote “present in binary” to “tested live.” |
| Aienux Store / disk | Reuse validated immutable-object results within a valid trust context; batch contiguous extent I/O. | Parent confirmed unit-by-unit read/write loops at `18e2765: native/store/store_engine.c:71-105,330-343`. Existing L341 covers Store; L199 covers the driver work. Preserve authentication, corruption rejection, I/O error order and crash recovery. |
| Aienux crypto | Better field representation and joint public-input scalar multiplication. | Existing L339 already reports a qualified branch. Do not create a duplicate fix from the old main snapshot; integration and boot status must be checked separately. No new crypto timing claimed here. |
| Interplane / Synapse / AEGIS | Batch pure work, reduce serialization and repeated hashes; reuse only context-complete immutable evidence. | Existing L342 owns Synapse/AEGIS efficiency. Interplane has explicit replay/duplicate checks; Crossveil states it never caches/upgrades/reuses a decision. AEGIS `policy_guard.rs:98-109` runs deterministic pre-dispatch checks before model opinion. **Do not cache permission decisions across changed grants, revocation, nonce, identity or world state.** |
| CI / agent orchestration | Content-addressed common work once, changed work only; share builds and one model load across qualification cases. | L307/L335 cover judge reuse; L337 polling; L384 merge train. Old audit “unowned” labels are stale. A reused result must bind the complete executable/environment inputs and retain negative controls. |
| Training / Allen / rig | Small search-policy models, fused optimizer updates, structured representations and sufficient-statistic features. | Canonical training main and `aien0/m20` resolve to the same inspected commit; the assigned L303 worktree was absent. No trained-policy advantage was verified. Allen says pre-alpha; rig engine README says in progress. Do not invent gains for missing implementations. |
| FORGE / energy | Reduce transfers, repeated preparation, checkpoint work and busy waiting while retaining qualification. | Existing L343. Reversible-computing theory is a motivation to inspect erasure and movement, not a measured energy gain on CMOS hardware.[11] |

The full `systems-audit.md` is the delegated historical input. **This table supersedes its “unassigned” owner statements for Store and crypto, and corrects its implication that sample-based search pruning establishes exact semantic equivalence.** Parent source checks and ledger reconciliation are distinct from independent hardware qualification.

## 5. What the original orbital ideas do and do not imply

A tetrahedral arrangement can suggest symmetry, balanced coordinates or an orthogonal hybrid basis. Wolfram checked that four tetrahedral **spatial directions** have off-diagonal dot products -1/3; they are not four orthogonal axes in three dimensions. Separately, the four-component normalized Hadamard basis is orthogonal. Neither construction reduces the dimension of a general computation by itself.

“Belt to poles” is not enough to identify a unique computational operator. If it means redistributing amplitude by a basis transformation, the useful question is whether the transformed problem has fewer outliers, lower rank, exploitable sparsity or cheaper operations after paying transformation costs. A visually striking orbital animation alone does not establish that.

Exchange symmetry can reduce a problem when its state and operators genuinely share that symmetry. Reordering arbitrary learned experts does not make them interchangeable, nor does geometric resemblance establish a valid rewrite.

## 6. What needs actual quantum or photonic hardware

- **Grover/amplitude amplification:** a quadratic oracle-query advantage, not free exhaustive search on a classical GPU. Preparation, coherent reversible oracle, reflections and measurement must be counted.[5]
- **Amplitude estimation:** potentially useful for estimation workloads with suitable coherent access; not obtained by replacing classical sampling with a statevector simulator.[5]
- **HHL/QSVT:** potentially useful for structured linear-algebra tasks with the right access model, conditioning, precision and small output observables. Preparing generic classical model weights and reading a full answer can remove the attraction. Tang's dequantization result is a warning to compare the access assumptions with strong classical baselines, not proof that all quantum algorithms lose.[2][3][4]
- **Quantum walks, annealing, QAOA and VQE:** problem-specific candidates, not general acceleration of program search or neural-network training. Count embedding, shots, coherent depth, classical optimization and time to a verified solution.[6][9][15]
- **Hamiltonian simulation:** a credible use of quantum computation for intrinsically quantum systems, distinct from accelerating the current inference engine.[14]
- **Photonic / continuous-variable / squeezed / cat states:** need a specified physical device and workload. Gaussian-state processes under the restricted operations in the cited theorem are efficiently classically simulable. Optical matrix multiplication is not by itself quantum advantage; conversion, precision, loss and control costs still count.[16]
- **Error-corrected/topological computation:** error correction consumes physical resources; below-threshold operation is not an AIEN application-speed receipt.[10]

A full complex128 statevector alone occupies **16 GiB at 30 qubits, 64 GiB at 32, and 128 GiB at 33** (Wolfram checked). This is a bound for that representation, not all quantum simulation: stabilizer, low-entanglement/tensor-network and Gaussian methods can exploit structure. Simulating arbitrary quantum parallelism is not a free route to hardware parallelism.

## 7. Existing quantum work must not be mistaken for a speed result

The project already has [AT-0 #358](https://github.com/aien-dev/omega-mv/issues/358) and [AT-1 #371](https://github.com/aien-dev/omega-mv/issues/371), the relational clock-system experiments. Their issue discussions distinguish software conformance, inconclusive blinded/outside replication claims and untested physical claims. AT-1's close-out explicitly says there is no automatic AT-2 and the engineering effort returns to finishing AIEN.

They are relevant prior research, not evidence that removing wall-clock time from a mathematical formulation removes hardware work. This audit does not reopen them or claim a discovery about physical time.

## 8. Recommended order and acceptance

1. **Zero-structure inventory, lossless representation, then exact execution probe.** Cheapest new lead with directly observed checkpoint structure. First determine whole-model prevalence and routing-weighted importance; do not project one expert onto the model.
2. **Rotation-aware low-bit representation.** Compare at equal total bit budget and quality, with a real candidate layout. Preserve an explicit approximate lane and account for nonlinearities and transform overhead.
3. **Finish and reuse existing exact-work reductions.** Resolve current owner/integration gates for Store, search, output filtering, common builds and shared qualification rather than building a second implementation.
4. **Targeted factorization/shared subspaces only where data support it.** Keep a dense control, activation-weighted error and a full storage/compute cost model.
5. **Quantum/photonic coprocessors as separate research, not an engine replacement recommendation.** A concrete workload and resource model are prerequisites; no hardware purchase or service change follows from this audit.

All performance comparisons must use the same model/task, hardware, precision contract and concurrency, and include preparation, metadata, readout/verification, bytes moved and joules. Wolfram's illustrative Amdahl checks show why a component win is not a system win: halving an 80%-of-runtime component gives 1.667x overall; halving a 20% component gives 1.111x. These are examples, not measured AIEN fractions.

## Reproduction and qualification status

```
OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 uv run --with numpy weight_probe.py
OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 uv run --with numpy sparsity_followup.py
OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 uv run --with numpy --with ml-dtypes validate_probe.py
```

The first two require read-only access to the checkpoint location named in the scripts; the third uses synthetic bytes only. No weights are committed. `checks.wl` and `wolfram-results.json` preserve the original Wolfram calculations; `geometry-check.wl` and its result preserve the final geometry check.

The probes ran successfully on the Mac CPU. Independent `ml_dtypes.float8_e4m3fn` comparison matched all **254 finite byte encodings**, including signed zero; both NaN codes were refused. Explicit Hadamard/inverse, quantizer and rank-one controls passed. This is an independent library oracle, **not** an independent human code review or a model-quality gate.

**Verdict:** static representation evidence and mathematical identities checked. Model accuracy, full-checkpoint prevalence, native kernel equivalence, latency, energy, hardware advantage and production integration remain **NOT_RUN / UNMEASURED** in this audit. Existing owners retain their separate qualification obligations.

## Broad quantum mechanism matrix

| Mechanism / where superposition enters | What can help classical systems (transferable) | Quantum-only requirements / limits |
|---|---|---|
| 1. **Relative phase + interference** (Hadamard/Fourier, phase kickback): amplitudes add/cancel to expose structure rather than read every branch. | FFT/WHT, phase-aware signal processing, structured transforms. | Coherent gates and matched oracle; measurements yield samples, not all amplitudes. |
| 2. **Encodings:** basis/amplitude/phase; orbital, spin, polarization, path, time-bin, momentum, energy | Representation, feature maps, packing, modal transforms; efficient distribution loading is special, not arbitrary.[13] | Encoding is not an algorithm. Amplitude loading can be costly; carrier choice does not change readout limits. |
| 3. **Entanglement / Schmidt rank / tensor networks** | MPS/TT, tree networks, low-rank factorization and optimized contraction; bond dimension is a complexity budget. Restricted entanglement permits efficient classical simulation.[1] | High entanglement can defeat these regimes, but does not itself prove application advantage. |
| 4. **Exchange symmetry / boson-fermion statistics** | Permutation invariance, symmetry-adapted bases, antisymmetric determinants; remove redundant degrees of freedom. | Physical identical-particle preparation/detection is hardware-specific; symmetry reduction itself is classical. |
| 5. **QFT / Hadamard / phase estimation** | FFT/WHT, spectral methods, modular arithmetic, eigensolvers. | Needs controlled coherent evolution and eigenstate overlap; Shor-style wins exploit periodic structure, not a generic transform. |
| 6. **Grover / amplitude amplification** | Importance sampling, branch-and-bound, heuristics; compare oracle cost too. | Quadratic query gain for unstructured search; coherent oracle/reflections and state prep are paid.[5] |
| 7. **Amplitude estimation / Monte Carlo** | Variance reduction, quasi-Monte Carlo, stratification, control variates; account for precision. | Quadratic sampling gain assumes coherent state prep, controlled oracle and sufficient depth; noise/measurement cost matter.[5] |
| 8. **Quantum walks** | Graph spectra, classical walks, sparsification, diffusion. | Requires coherent walk/oracle and target readout; oracle separations do not imply generic graph gains.[6] |
| 9. **HHL / quantum linear algebra** | Krylov/preconditioned solvers, low-rank methods, randomized linear algebra; define output needs. Dequantization matches a candidate under strong access assumptions.[2] | Sparse, well-conditioned operator; efficient access and prepared RHS; output is a state/observable, not all entries of x.[3] |
| 10. **Block encoding / QSVT** | Polynomial filters, matrix-free operators, low-rank/spectral transforms, stability analysis. | Block-encoding access/normalization, ancillas, controlled gates and approximation degree can dominate.[4] |
| 11. **Adiabatic / annealing / QAOA / VQE** | Variational optimization, warm starts, symmetry ansätze, graph decomposition, hybrid loops; VQE is hybrid.[9] | Requires quantum hardware; ansatz, shots, embedding/control and readout matter. No general annealing speedup; compare full time-to-solution.[15] |
| 12. **Hamiltonian simulation / Trotterization** | Product formulas, operator splitting, sparse exponentials, commutator-aware schedules. | Local Hamiltonian encoding, synthesis and error budget; most compelling for quantum-system simulation.[14] |
| 13. **Continuous-variable squeezed/cat states; photonics** | Optical linear algebra and transforms may inspire classical accelerators; distinguish coherent optics from quantum. | Restricted Gaussian preparations, quadratic operations and canonical measurements are classically simulable; non-Gaussianity, loss, detectors and task matter. Photonic multiplication alone is not quantum advantage.[16] |
| 14. **Simulation boundaries: stabilizer/Gaussian circuits, low treewidth/entanglement** | Identify structures enabling classical simulation; use contraction and stabilizer/Gaussian algebra.[1][16] | Non-Clifford, high treewidth/entanglement or non-Gaussian states may be hard to simulate; hardness is not practical advantage. |
| 15. **Decoherence / QEC / surface or topological codes** | Error budgets, robustness, redundancy, decoder co-design. | Encoding, syndrome measurement and decoding cost resources; below-threshold is necessary, not sufficient. Recent surface-code results retain a large gap to practical algorithms.[10] |
| 16. **Reversible computation / Landauer** | Reduce writes/erases and data movement where worthwhile; include energy accounting. Logical reversibility can avoid erasure in principle.[11] | Landauer concerns irreversible erasure, not quantum-device energy. Reversible methods may trade time/memory/control for energy. |
| 17. **Measurement / readout / no-signalling** | Return sufficient statistics; count output size and communication. | Shots have noise; vector/matrix output costs at least output size. Entanglement cannot signal faster than light.[12] |

## Sources

[1] https://arxiv.org/abs/quant-ph/0301063v2 — Efficient classical simulation of slightly entangled quantum computations
[2] https://arxiv.org/abs/1807.04271 — A quantum-inspired classical algorithm for recommendation systems
[3] https://arxiv.org/abs/0811.3171 — Quantum algorithm for linear systems of equations
[4] https://arxiv.org/abs/1806.01838 — Quantum singular value transformation and beyond: exponential improvements for quantum matrix arithmetics
[5] https://arxiv.org/abs/quant-ph/0005055 — Quantum Amplitude Amplification and Estimation
[6] https://arxiv.org/abs/quant-ph/0209131 — Exponential algorithmic speedup by quantum walk
[7] https://arxiv.org/abs/2404.00456 — QuaRot: Outlier-Free 4-Bit Inference in Rotated LLMs
[8] https://arxiv.org/abs/2307.13304 — QuIP: 2-Bit Quantization of Large Language Models With Guarantees
[9] https://arxiv.org/abs/1304.3061 — A variational eigenvalue solver on a quantum processor
[10] https://www.nature.com/articles/s41586-024-08449-y — Quantum error correction below the surface code threshold
[11] https://www.cs.princeton.edu/courses/archive/fall06/cos576/papers/bennett73.html — Logical Reversibility of Computation
[12] https://arxiv.org/abs/quant-ph/0212023 — Quantum Information and Relativity Theory
[13] https://arxiv.org/abs/quant-ph/0208112 — Creating superpositions that correspond to efficiently integrable probability distributions
[14] https://doi.org/10.1126/science.273.5278.1073 — Universal Quantum Simulators
[15] https://www.physics.ucsb.edu/~martinisgroup/papers/Ronnow2014.pdf — Defining and detecting quantum speedup
[16] https://arxiv.org/abs/quant-ph/0109047 — Efficient Classical Simulation of Continuous Variable Quantum Information Processes
