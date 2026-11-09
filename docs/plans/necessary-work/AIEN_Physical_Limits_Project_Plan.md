# AIEN: Make the Necessary Work the Limiting Factor

Research and execution plan • 18 October 2026 • Proposed program, not a claim of achieved performance

## 1. The objective

Make AIEN accomplish a defined objective with the least necessary computation, information movement, elapsed time, and energy consistent with a declared correctness contract. Explain the remaining distance from defensible mathematical and physical limits through proofs and controlled experiments.

The order of work is deliberate:

1. Determine whether the computation is necessary at all.
2. Replace discovery with a reusable result or a cheaper checked certificate where possible.
3. Find a better algorithm or representation for the remaining work.
4. Minimize communication, repeated inference, and avoidable dependencies.
5. Execute the irreducible remainder efficiently on the actual machine.

Omeganese is available throughout this program. Its purpose is to express useful semantics, enable transformations, and carry checkable evidence. A language rewrite is justified by a demonstrated reduction in work or improvement in assurance, not by the language's name.

This plan uses “physics” to mean the scientific discipline. References to the repository named physics are only existing source dependencies; that repository does not define the scientific limits.

**The operational commitment:** no unexplained bottleneck is accepted as a physical limit. Every important gap receives an owner, competing explanations, a discriminating experiment, and a next-review condition. Resource limits may defer an investigation; they do not convert ignorance into a theorem.

**The necessary qualification:** I cannot promise that mathematics will become the only obstacle to every possible objective. Missing information, external systems, finite energy and memory, and undecidable or unresolved problems remain relevant. I can make a rigorous, progressively stronger statement for specified task families, hardware, and operating conditions. An unsuccessful search is not an impossibility proof.

## 2. What success means

The primary unit is a **correctly completed objective**, not a token. A solution that eliminates 90% of model calls can be more valuable than a kernel that generates tokens twice as fast. Percentages here illustrate the comparison; they are not forecasts.

Maintain three separate contracts:

| Track | What must remain equivalent | What may change | Main acceptance evidence |
|---|---|---|---|
| A: Exact execution | Declared finite semantics, outputs, traps, and permitted effects | Representation, schedule, storage, proven rewrites | Proof or bounded exhaustive verification for the supported domain; measured execution |
| B: Exact model inference | Pinned model/runtime semantics; deterministic token sequence or target sampling distribution, explicitly distinguished | Drafting, batching, cache layout, scheduling | Numerical and sequence controls; derivation of sampling correctness; statistical diagnostics are supporting evidence |
| C: Objective-level efficiency | Acceptance criteria and quality on the declared task distribution | Model choice, amount of reasoning, symbolic methods, reusable skills, answer wording | Independent task acceptance, paired held-out evaluation, error analysis |

Track C is the main agent objective. Tracks A and B supply reliable mechanisms. A task-equivalent result must never be labeled bit-identical inference. A numerically close result is not automatically semantically identical. Distribution preservation does not imply the same sampled text for the same random seed.

Record these metrics separately:

- Objective success, failure, and abstention rates; no success-conditioned reporting that hides failed attempts.
- Request-to-accepted-result latency, including retries and verification; p50 and p95.
- Total CPU time, GPU time, and energy across all attempts divided by accepted objectives; always accompanied by success rate.
- Time to first useful verified action, distinct from time to first displayed token.
- Cold-start TTFT, warm TTFT, and prefix-hit TTFT; queueing included and excluded as separate views.
- Sustained output tokens/sec and inter-token latency; actual generated token IDs, not network chunk counts.
- Model calls, input and output tokens, planner expansions, certificate bytes, checking time, retrieval time, and cache hit/miss costs.
- Bytes crossing each measured memory boundary, peak live memory, and critical dependency depth.
- Offline search, proof generation, compilation, tuning, and training costs, reported both raw and amortized.

No single weighted score replaces this table. Present a Pareto frontier: improvements in latency, cost, and quality that do not conceal regressions in the other dimensions.

## 3. The starting evidence

Repository inspection was read-only. No new GB10 measurements were performed for this plan. Existing receipts refer to their own commits, flags, models, and hardware conditions; they are not automatically measurements of today's default branch.

Reviewed source anchors: Omega f4a9849fb127f8d2d664dfc56890752ad180c507 and sovereign-core e6852de85dfe503347d37ed2438d1ce6f1ac8c3a, with individual historical receipts identified below. Re-pin all dependencies before executing this program.

| Finding | Evidence | Consequence for this program |
|---|---|---|
| Native decode command lists already exist | Omega `src/omega_gpu_decode_graph.c`, `src/omega_gpu_cmdlist.c` [G1] | Use existing machinery; measure residual costs before rebuilding it |
| A short-context historical trace spends about 83% of its instrumented span in projections | 24.48 ms graph span; projections approximately 20.35 ms; recording 48.6 microseconds [G2] | Projection work and weight movement dominate this case; host recording is a small opportunity |
| Whole-prompt prefill and graph decode already produced gains | Historical requalification: 2,048-token TTFT approximately 32.1–32.2 s to 0.85–0.88 s; graph-on approximately 39.5–42.6 tokens/s [G3] | Preserve and requalify these paths; do not count them as new proposed discoveries |
| Draft verification has a promising but limited result | Qwen3-8B: B=2, 89.731 s to 57.358 s with identical output; larger blocks diverged; one task and one run per setting [G4] | Reproduce, resolve arithmetic-path differences, and test amortization on held-out workloads |
| Prefetch was not an end-to-end win | Two-layer cached baseline approximately 3.95–3.98 ms versus prefetch 4.06–4.08 ms in one requalification [G5] | Preserve the negative result; a new prefetch proposal must explain what changed |
| Reusable plans exist as a bounded host-side mechanism | `rx_plan.h/.c`: explicit applicability predicates, candidate/verified/stale states, reference execution for candidate reuse, cost counters, fixed template capacity [G6] | Extend and qualify a real starting point; do not invent a second plan cache |
| Typed state projection exists | `rx_projection.h`: declared needs, derived values, recallable references, protected evidence [G7] | Test whether projections are sufficient; “smallest” in a comment is not a minimality proof |
| Independent checking and LRAT support exist, with restricted scope | `checker2`, one-layer receipt specification, and `c2_lrat.c` [G8] | Use the checker as a starting point; preserve explicit proof-domain limitations |
| Checked IR is not yet proof of correct executable translation | Receipt classes explicitly bind executable bytes by hash without translation validation; dependency receipt resolution also remains open in v1 [G8] | Close this evidence boundary before using receipts to justify broad elimination of rechecking |
| Omega is research-grade; general compiler and runtime qualification remain incomplete | Current README distinguishes implemented, historical, and qualified results [G9] | Build narrow, qualified slices; avoid a wholesale language migration as the first milestone |

The inspected sources use “Omega,” “Omega surface language,” and “Omega Systems Core.” This plan uses the user's term **Omeganese** for the intended expression and execution route. Phase 0 must map that term to an exact frontend, IR, backend, and supported semantic subset. The older surface-language audit is historical and is not treated as a complete description of the current OSC compiler.

The architecture authority linked by the repositories could not be retrieved at its referenced path in this session. Therefore this is a proposed program to reconcile with that authority, not a replacement for its existing roadmap. Component owners are roles below; no individual's ownership is invented.

## 4. Four different kinds of limit

| Limit class | Example | What establishes it | What does not establish it |
|---|---|---|---|
| Mathematical | A task needs a certain number of queries in a stated oracle model | Proof with explicit assumptions and quantifiers | A slow solver, benchmark plateau, or timeout |
| Algorithm-specific | Communication required by a chosen computation DAG with bounded fast memory | A lower-bound argument for that DAG/model | Claiming the same bound for every equivalent algorithm |
| Hardware | Finite transfer, issue, compute, storage, and dependency capabilities | Hardware specification plus model; calibrated measurements constrain what is attainable | Treating the fastest measured run as proof of maximum capability |
| Implementation | Redundant work, bad layout, repeated inference, excessive barriers | Traces and causal experiments | Calling software behavior a law of physics |

Every bound record must include: task, input family, allowed preprocessing, storage budget, arithmetic semantics, error tolerance, machine assumptions, cold/warm state, proof or source, and conditions that invalidate the bound.

For a specified algorithm and machine, a coarse lower bound on latency can take the form:

`T_actual >= T_lower = max(Q_min / B_cap, F_min / P_cap, L_critical, T_mandatory_external)`

Here Q_min and F_min must actually be necessary under the stated assumptions; B_cap and P_cap must be appropriate upper capacities for the relevant operations and transfers. Taking a maximum handles potential overlap; adding everything would double-count it. Tighter bounds must model serial stages and shared-resource contention. LPDDR reads and writes, for example, cannot independently consume the same total bandwidth budget.

Measured sustainable microbenchmarks are **attained reference performance**, not proofs of upper capacity. Keep a separate engineering model using those references. A gap to an attainable reference is actionable; a gap to a weak mathematical bound may simply expose that the bound is weak. Neither is “percentage of physics” without qualification.

The earlier estimate of approximately 82 tokens/sec used 3.34 GB of nominal projection weights divided into a 273 GB/s hardware specification. It is a conditional, optimistic weight-streaming estimate for one-token execution, excluding other costs. It is not a universal speed limit. Weight reuse, compression, different precision contracts, and fewer required model calls all challenge its assumptions. [G2, H1]

Do not begin with Landauer-scale limits or raw advertised AI FLOPS. Such quantities do not yet give a useful tight bound on this agent's task latency. Begin with a defined task, its necessary information, and the machine's actual execution and communication constraints.

## 5. Mathematical work reduction comes first

### 5.1 Separate finding from checking

Use expensive search, learned reasoning, or external mathematics to propose a result. Ask a smaller independent checker to validate the result against an explicit specification. Preserve the accepted result, its assumptions, and the evidence needed for reuse.

This does not make every problem cheap. Proof search may be hard; certificates may be large; checking may be expensive; and the formal specification may omit what the user actually intended. Measure all four. A checked proof establishes its formal statement, not the accuracy of an informal translation or the truth of unchecked environmental facts.

Start with three CPU-sized domains:

| Domain | Expensive work to challenge | Cheap evidence to investigate | Important limitation |
|---|---|---|---|
| Bounded integer/bit-vector kernels | Repeated evaluation or repeated proof search | Rewrite derivation, exhaustive small-domain check, restricted SAT certificate | Overflow, signedness, traps, and preconditions are part of semantics |
| Repeated dependency-constrained plans | Searching the same arrangements or workflows repeatedly | Applicability predicates plus postcondition checking | A previously valid plan can become invalid when state or authority changes |
| Structured mathematical objectives | Long natural-language reasoning for arithmetic, identities, or finite constraints | Exact arithmetic witness, symbolic derivation, or solver certificate | A substitution check proves a candidate satisfies an equation, not uniqueness or completeness |

Illustrative research exercise: a loop computing an integer sum may be replaceable by a closed form. The proof must include range and overflow behavior; an algebraic identity over integers does not automatically preserve a finite-width implementation. Compare operation count, proof cost, and actual execution. This is an example to formalize, not an assertion about an existing AIEN kernel.

### 5.2 Reuse knowledge under explicit assumptions

Create a reusable result record containing:

- Formal problem and result; semantic version and input domain.
- Preconditions, environmental dependencies, and exact data identities.
- Proof or certificate, checker identity, and checked property.
- Executable realization identity and its translation evidence, if execution is involved.
- Retrieval/application cost, measured cold and warm benefit, and break-even reuse count.
- Invalidation triggers; reasons for declining reuse; fallback path.

Hash identity is a binding mechanism. It is not proof that two arbitrary programs mean the same thing. Canonicalization recognizes the equivalences it implements; general program equivalence is not solved by hashing.

For one candidate shortcut, with a baseline per-use cost C_b, one-time discovery/validation cost C_s, and actual per-use shortcut cost C_r including lookup, checks, execution, and expected fallback:

`N_break_even > C_s / (C_b - C_r)`, provided `C_b > C_r`.

If the denominator is nonpositive, the shortcut does not pay back under that workload. Report separate time and energy break-even points. Include failed candidate discovery in the campaign total, and avoid assuming an infinite future reuse count.

### 5.3 Search for equivalent formulations

Explore algebraic rewrites, constant propagation, partial evaluation, common subexpressions, loop invariants, sufficient statistics, incremental updates, and specialized domain algorithms. Equality saturation is a candidate technique, not an obligatory new dependency. Its extracted expression is optimal only relative to the explored equivalences and cost model; it is not globally optimal mathematics. [R3, D2]

Every rewrite needs a checked semantic domain. Real-number associativity cannot justify reordering floating-point sums while claiming bitwise equivalence. Preserve effects, exceptions, NaNs, signed zero, rounding, and aliasing where applicable. If a relaxed numerical contract is useful, open a separate evaluation track.

Use manual derivation first when it can eliminate an entire computation. Then bounded CPU search. Use the GPU only when the question is about GPU behavior or the smaller methods have a documented limitation.

## 6. The experimental program

These are proposed experiments, not completed work. Every row becomes a project item with the experiment record in section 10. The owner codes are defined in section 12. Promote only after the common correctness and measurement gates in section 9.

| ID / priority | Hypothesis and predicted observation | Discriminating experiment and controls | Decision / deliverable | Owner |
|---|---|---|---|---|
| E01 / P0 | Significant objective time is repeated discovery or unnecessary model invocation | Trace complete objectives; replace model calls with recorded outputs in a local replay solely to bound possible savings; retain real quality evaluation separately | Cost inventory and causal upper opportunity estimate, not a deployable replay result | EXP + AGENT |
| E02 / P0 | A CPU checker can validate selected mathematical outputs more cheaply than another model pass | Compare model self-check, exact direct computation, and candidate-plus-certificate; include wrong witnesses, malformed proofs, and specification variants | Per-domain checker cost, acceptance limits, and a decision whether certificates are actually worthwhile | MATH |
| E03 / P0 | Existing plan reuse removes repeated search with lower total cost | Cold solve, warm same-instance, new bindings, and changed preconditions; compare against existing `rx_plan` baseline; count retrieval and validation | Held-out reuse benefit and invalidation coverage; no general-agent claim from a toy domain | AGENT |
| E04 / P0 | Some repeated computations have provably cheaper formulations | Manually derive and independently check 3–5 hot pure operations; benchmark original and transformed versions over boundary inputs | Small library of checked reductions with operation counts and exact domains | MATH + OMEGA |
| E05 / P0 | Current IR evidence is insufficient to trust executable substitution | Corrupt native instructions while keeping valid IR; build translation-validation slice for a small supported instruction subset; unsupported constructs refuse | Checked relation between IR and executable for that subset; remaining unsupported scope explicit | OMEGA + REVIEW |
| E06 / P1 | Bounded rewrite search finds reductions missed manually | Fixed CPU budgets; compare manual rules, greedy rewrites, and bounded equality exploration; proof-check each accepted derivation | Net savings including search; rewrite set and counterexamples; no “optimal” label on timeout | MATH + OMEGA |
| E07 / P1 | Typed projections reduce reasoning inputs without losing needed facts | Compare full state, declared projections, and projections with recall; plant required facts outside naive summaries; vary state after caching | Sufficiency failures, recall overhead, reduced input bytes/tokens, and objective quality | AGENT |
| E08 / P1 | Incremental verification can avoid checking unchanged dependencies | Change one dependency at a time; compare full recheck with dependency-indexed recheck; include hidden/stale dependency mutants | Proof of invalidation rules for supported structures plus measured cost benefit | MATH + AGENT |
| E09 / P0 | The performance apparatus can distinguish host time, device time, and observer effects | Null kernels, dependent/independent chains, timestamp-on/off, known sleeps/work, cold/warm runs | Clock/measurement calibration and uncertainty; reject inconsistent timelines | EXP + GPU |
| E10 / P0 | Projection kernels leave an identifiable gap to attainable native memory throughput | Read-only streaming, gather, read/write, and dependency microbenchmarks using actual mappings; sweep size across caches and production shapes | Hardware reference atlas with conditions; no claim of absolute maximum | GPU |
| E11 / P1 | FP8 load scheduling, conversion, or occupancy explains the projection gap | Isolate load-only, conversion-only, reduction-only and full kernels; sweep variant 1/2, block shape and registers; preserve operation order | Per-shape dispatch only where full-model uninstrumented latency improves | GPU |
| E12 / P1 | Uncached intermediates or excessive synchronization cause avoidable traffic | Separate GPU-only scratch from host mailboxes; compare visibility-correct barrier variants; run stale-data mutants and repeated stress | Qualified memory/barrier contract; retain baseline if coherence or net benefit fails | GPU + OMEGA |
| E13 / P1 | Selected fusion removes traffic and launches without harmful occupancy loss | Candidate gate/up+SwiGLU or residual+consumer versus existing chain; include register and full-step measurements | Keep only end-to-end winners; existing combine+norm fusion is baseline | GPU |
| E14 / P1 | Multi-token verification reuses weight traffic enough to outweigh rejected work | Reproduce B=2 result; test larger blocks after arithmetic-path investigation; compare draft strategies, no-draft control, and adaptive depth | Accepted tokens/ms including draft, validation, rollback and KV repair; qualify each model separately | GPU + AGENT |
| E15 / P1 | TTFT can fall through reuse or reduced prefill work | Cold/warm/prefix-hit/miss matrix, short and long prompts; profile routing, prefill, initial head and startup separately | TTFT frontier with explicit numerical contract and tail-latency limits | GPU + AGENT |
| E16 / P2 | Repeated tool workflows need fewer model round-trips | Compile one pure/read-only workflow into checked transitions; compare against per-step model control; test changed schemas and unexpected observations | Objective latency and model calls including fallback; fresh checks before effects | AGENT |
| E17 / P2 | Specified compression reduces total cost after decode/check overhead | Test lossless representations or proven task-specific summaries first; include entropy/incompressible controls and decompression traffic | Net latency/energy benefit and explicit semantics; lossy methods remain Track C | MATH + GPU |
| E18 / P2 | Hardware-tailored superoptimization helps a small recurring kernel | Search a bounded instruction space on CPU, verify candidates, run a small shortlisted set on chip | Search-space-specific best result and amortization; no unrestricted optimality claim | OMEGA + GPU |
| E19 / P0 recurring | Proposed bottleneck explanations predict behavior outside the fitted case | Predict effects of size, context, cache, dependency, or supported clock changes; test unseen conditions | Explanation retained, narrowed, or falsified; residual stays open | EXP + REVIEW |
| E20 / P0 release | Combined improvements improve objectives rather than isolated demos | Frozen held-out objective suite, ablations, cold/warm results, sustained thermal run and deliberate failure paths | Reproducible release dossier and rollback decision | EXP + REVIEW |

Run E02–E04 before committing to large new compiler machinery. Run E09–E10 before a broad kernel search. E05 gates trusted executable substitution, but need not block mathematical exploration or untrusted candidate generation. E14 depends on a sound inference contract, not merely faster matrix operations. E20 requires both the work-reduction and execution tracks to be evaluated together.

The prefetch hypothesis has a recorded negative result [G5]. It does not disappear from the ledger. Reopen it only with a specific changed premise, such as a different overlap schedule or cache residency, and predict why the outcome should change.

## 7. Omeganese's role and the proof boundary

Use the existing Omega plan and projection mechanisms wherever they fit. Treat source syntax as replaceable. The semantic contract, proof obligations, and measured behavior are the durable artifacts.

The first useful slice should carry:

1. A typed pure operation or bounded plan with explicit preconditions and postconditions.
2. A semantics version covering integers, floating point where supported, traps, memory, and effects.
3. An untrusted producer of rewrites, proofs, or specialized realizations.
4. An independent checker of the exact claimed relation.
5. Binding of checked inputs, dependencies, proof, executable, target, and checker version.
6. A runtime applicability check and a correct fallback.

There are distinct proof obligations:

| Boundary | Required claim | Current planning treatment |
|---|---|---|
| Objective to formal statement | The specification captures what counts as success | Domain-specific review and independent acceptance; not assumed solved by the compiler |
| Original expression to transformed expression | Equivalent under named preconditions and finite semantics | Small checked rewrite system first |
| IR to machine code | Executable implements the checked IR | Explicit missing translation-validation work, scoped by E05 |
| Plan to current world | Preconditions and dependencies still hold | Existing plan applicability machinery; stress and extend its scope |
| Certificate to declared property | Checker validates the property actually claimed | Keep current restricted LRAT scope visible; do not relabel no-trap as functional correctness |
| Completed workflow to accepted objective | Observable postconditions hold | Independent final verifier; successful termination alone is insufficient |

The current receipt specification's class 2 proves a restricted no-trap property under requires clauses, not arbitrary program equivalence. Its bit-blaster refuses unsupported operations, and its LRAT checker supports a restricted proof form. Reuse that discipline rather than widening claims silently. A signature proves provenance, not correctness. [G8]

Proof discovery may remain untrusted. The checker must be versioned, reviewed, tested with deliberately invalid proofs, and small enough to inspect. Minimize shared implementation between producer and checker, but acknowledge shared semantics and formalization errors. A correct checker for an incorrect statement still checks the wrong thing.

## 8. Workloads and controls

Build a versioned suite around real objectives before tuning. Use synthetic cases to isolate causes, not to replace objective-level evaluation.

| Family | Initial cases | Required partitions |
|---|---|---|
| Formal CPU tasks | Bounded arithmetic transformations, finite constraints, plan applicability | Small exhaustive domains; larger boundary and random cases; valid/invalid certificates |
| Repeated objectives | Same plan with new inputs; cached result; state change; stale dependency | First occurrence, useful repeat, false match, miss, invalidated entry |
| Inference | Current 8B dense and 30B MoE paths, separately | Greedy/sampled; 1, 20, 512, 2,048-token prompts initially; longer supported contexts later; short/long generation |
| Agent tasks | Read-only repository query, structured data transformation, bounded planning, tool workflow, a task needing new evidence | Familiar task family, unseen instances, genuinely novel objective, ambiguous or unanswerable case |
| System behavior | Startup, concurrency, interruptions, cache pressure, long thermal run | Idle exclusive device versus controlled contention; warm versus cold; queue-inclusive latency |

Use a development partition for tuning and a frozen held-out partition for decisions. Split repeated-task families so that exact answer memorization is visible rather than mistaken for generalization. Report warm reuse explicitly; it is a legitimate gain when the workload really repeats.

Task-level quality needs a specified noninferiority margin and confidence procedure before the campaign. Exact domains permit no observed mismatch and require the promised formal evidence. Statistical tests do not prove zero error or exact distribution identity. For open-ended objectives, state the evaluator's uncertainty and retain manual review of disagreements.

## 9. Measurement and promotion gates

**Gate G0 — Reproducible baseline.** Pin source, dependency locks, executable and model hashes, input set, device/firmware/driver, memory mode, precision, flags, clocks, power mode, and temperature. Native execution must be positively identified. Historical or dirty-tree receipts are preserved but not relabeled as clean candidate qualification.

**Gate G1 — Trustworthy measurements.** Calibrate CPU/GPU timestamp relationships where cross-domain timing is used. Measure tracing overhead. Pair diagnostic runs with uninstrumented outcome runs. Record whether profiling changes caches, clocks, replay, or serialization. Context7's NVIDIA documentation explicitly identifies these interventions [D1]. Nsight compatibility with the native submission path is unverified; use existing native timestamps and controlled experiments if unsupported. Lack of counters leaves uncertainty, not permission to invent them.

**Gate G2 — Correctness.** Apply the selected Track A/B/C contract. Include mutated proofs, stale cached inputs, wrong model/tokenizer identities, altered code bytes, numerical boundary cases, invalid effect ordering, and omitted dependencies. A faster incorrect candidate is a failed experiment.

**Gate G3 — Detectable benefit.** Start with a short pilot to estimate variance. Predeclare minimum worthwhile effect, repetition count or sequential stopping rule, and confidence method. Interleave A/B order and randomize where appropriate. Use independent request/run units; adjacent tokens within one run are not independent repetitions. For p95, collect enough requests to estimate its uncertainty rather than quoting a handful of samples.

**Gate G4 — Full cost.** Include compilation, search, proof generation/checking, data preparation, retries, misses, fallback, and amortization. Report CPU and GPU work even if one is hidden behind the other. Concurrency can reduce wall time while increasing total energy; show both.

**Gate G5 — Causal explanation.** The proposed mechanism must predict an unseen perturbation, such as working-set scaling or dependency-chain sensitivity. A curve fit to the original trace is not enough. Negative residuals or faster-than-bound results trigger a measurement or bound audit.

**Gate G6 — Independent reproduction and integration.** A second reviewer reproduces the result from preserved inputs and commands. Full-agent evaluation and sustained runs pass. Promote through the project's normal review and candidate process; retain an immediate fallback to the last qualified realization.

No arbitrary percentage is called the physical limit. A scoped “near the limit” claim requires a defensible bound, a measured interval, an uncertainty budget, and a statement of all excluded alternatives. A plateau is recorded as “best observed under this search budget.”

## 10. The evidence ledger

Use one append-only record per experiment. The following is a proposed schema, not an assertion that it is implemented:

```text
experiment_id / parent_id / owner / reviewer / date
objective_family / contract_track / exact_semantics_version
source_pins / executable_hash / model_hash / checker_identity
hypothesis / competing_explanations / predicted_measurements
bound_id / proof_assumptions / invalidation_conditions
baseline / intervention / controls / workload_partition
hardware_state / cache_state / instrumentation_state
budget: person_hours, cpu_hours, gpu_hours, storage, search_nodes
measurement_protocol / uncertainty_method / stopping_rule
raw_receipts / commands / outputs / negative_controls
discovery_cost / verification_cost / execution_cost / reuse_count
result: PASS, FAIL, NOT_RUN, BLOCKED_HARDWARE,
        BLOCKED_OPERATOR, MISSING_IMPLEMENTATION
claim_strength: proven_in_scope, measured, inferred, unresolved
remaining_gap / next_discriminating_experiment / revisit_trigger
```

Keep the repository's result vocabulary and add claim strength as a separate field. A PASS means the declared experiment gate passed, not that a global optimum was proved.

The program dashboard needs five views: objective quality/cost frontier; cold/warm timing; work eliminated; hardware execution gap; and unresolved explanations. The last view is a first-class deliverable.

When an explanation fails:

1. Preserve the failed prediction and raw receipts.
2. Audit measurement and correctness first.
3. Challenge the algorithm's unnecessary-work assumptions.
4. Search literature, existing source, and alternative formulations.
5. Construct the smallest example that separates the remaining explanations.
6. If blocked, name the missing observation or capability and set a revisit trigger.

Deferral is allowed; “physically impossible” requires stronger evidence. An unresolved gap is a research obligation, not proof that a particular compression exists.

## 11. A phased delivery plan

Indicative duration: a first 12-week campaign with four contributor roles and independent review availability. This is a planning envelope, not a forecast that mathematical discoveries will arrive on schedule. With fewer contributors, retain gate order and reduce concurrent experiments. Weeks are relative to program start.

| Phase | Window | Work and concrete deliverables | Exit gate |
|---|---|---|---|
| 0: Define and reproduce | Week 1 | Contract tracks; 3 CPU objective families; initial agent/inference suite; pins and apparatus check; map Omeganese/OSC surfaces; reconcile authoritative roadmap | G0, initial G1; every baseline status explicit |
| 1: Remove work cheaply | Weeks 2–3 | E01–E04; checked arithmetic example, plan-reuse campaign, certificate-vs-direct-evaluation comparison; first break-even ledger | At least one defensible reduction or a falsified hypothesis with a decisive next experiment; no forced success quota |
| 2: Establish trustworthy substitution | Weeks 3–6 | E05–E08; narrow translation-validation slice; checked rewrite set; reuse invalidation; projection sufficiency evaluation | G2 and G4 for supported substitutions; unsupported cases use baseline |
| 3: Explain hardware gaps | Weeks 2–6, alongside CPU work | E09–E13; native hardware atlas; component attribution; shortlisted load/layout/fusion experiments | G1, G3, G5 for each retained kernel change |
| 4: Reduce necessary model passes | Weeks 6–9 | E14–E17; exact draft verification qualification; TTFT/cache campaign; one reusable read-only tool workflow | Model-specific correctness; objective-level benefit including cold costs and fallback |
| 5: Integrate and challenge | Weeks 10–12 | E18 only if reuse economics justify it; E19/E20; ablations; independent rerun; unresolved-gap review | G6 and a scoped release dossier; no universal-optimality claim |
| Continuing research | After first campaign | Reopen unresolved gaps with new evidence; broaden verified semantic and task coverage | Each extension earns its own evidence |

Critical dependencies: contract and baseline before optimization claims; semantics and translation evidence before trusted executable reuse; measurement calibration before hardware attribution; arithmetic consistency before exact larger-block verification; full objective suite before promotion.

## 12. Ownership, resources, and work allocation

| Role | Accountability |
|---|---|
| MATH: algorithms/formal-methods lead | Necessary-work arguments, rewrites, certificates, proof assumptions, counterexamples |
| OMEGA: compiler/runtime lead | Omeganese semantic slice, realization binding, translation validation, integration with existing IRs |
| GPU: performance lead | Native apparatus, memory/compute experiments, kernel correctness and sustained execution |
| AGENT: objective/runtime lead | Plan reuse, state projection, tool workflows, end-to-end acceptance and quality |
| EXP: experimental owner | Workload design, statistical protocol, reproducibility, ledger and gap accounting; may be shared with a contributor |
| REVIEW: independent reviewer | Challenge specifications, reproduce selected results, review evidence before promotion |

One person may cover multiple roles, but a candidate's author should not be its sole acceptance reviewer. Named assignments must come from the actual team.

Use existing hardware first: ordinary CPU host for proofs and small searches; the existing GB10 for questions requiring that device. No new hardware purchase is justified by this plan alone. No production Python or CUDA dependency is proposed; existing repository constraints remain in place. External research tools supply ideas or offline evidence, not an automatic runtime dependency.

Initial allocation proposal: 50% contributor effort on work elimination and semantic assurance, 25% on measurement and hardware, 25% on integration and independent replication. Reallocate based on measured objective cost, not attachment to a track.

Book exclusive GB10 experiment slots; do not compare uncontrolled concurrent jobs. Preserve native-job operational rules and do not kill chip jobs mid-run. Budget each campaign after a pilot in CPU/GPU hours and storage; do not invent a monetary forecast without actual labor and energy rates.

Weekly review: one page per active hypothesis showing prediction, observation, total cost, and next discriminator. Every two weeks choose work by expected objective benefit, uncertainty reduced, and experiment cost. A negative result that rules out an expensive direction is a valid delivery.

## 13. First ten working days

| Day | Action | Reviewable output |
|---|---|---|
| 1 | Freeze the three equivalence tracks, primary objective families, and current candidate pins | Signed-off experiment charter and baseline inventory |
| 2 | Audit existing plan cache, projection, checker, and inference seams; map source to actual serving paths | Implemented/integrated/qualified matrix; missing boundaries named |
| 3 | Trace a small real-objective sample; record model calls and repeated work | Cost ledger with no speedup claim |
| 4 | Derive 3–5 candidate work reductions manually; specify their domains and counterexamples | Proof sketches and independent checking plan |
| 5 | Run CPU comparisons: direct solve, certificate check, cached reuse; include invalid inputs | E02–E04 pilot receipts and break-even estimates |
| 6 | Calibrate native timers and observer overhead; reproduce one historical inference baseline | E09 apparatus report and old/new comparison |
| 7 | Measure native streaming and dependency baselines with production memory modes | E10 first hardware reference atlas |
| 8 | Select one work-reduction candidate and one hardware hypothesis by predicted value | Two preregistered confirmatory experiments |
| 9 | Run independent controls and held-out cases; identify translation evidence needed for promotion | Correctness and uncertainty report |
| 10 | Review results, including failures; assign the next two-week campaign | Initial decision record and unresolved-gap ledger |

Do not spend these ten days rewriting the stack. The output is evidence about which work should disappear and which physical resource actually limits the remainder.

## 14. Risks that can invalidate the program's conclusions

| Risk | Prevention and required response |
|---|---|
| Checking the wrong formal statement | Independently review objective-to-specification mapping; retain observable acceptance tests |
| Proof search costs more than it saves | Measure discovery and failures; enforce search budgets and realistic reuse break-even |
| “Verified” means a test passed once | Label proof scope, empirical checks, and reference comparison distinctly |
| Canonical identity mistaken for semantic equivalence | Require a checked relation for transformations; hash only binds declared objects |
| Warm cache mistaken for general reasoning | Separate cold, repeat, novel, and invalidated cases |
| Floating-point transformations change decisions | Keep exact and relaxed tracks separate; test near-ties and row-count changes |
| Overfitted kernel tuning | Hold out shapes/contexts and repeat complete objective runs |
| Double-counted timing savings | Model overlap and shared resources; use critical-path measurements |
| Profiler changes the workload | Instrumentation ablation; uninstrumented acceptance runs |
| New model/smaller precision silently changes task | Requalify Track C quality; do not inherit Track B claims |
| Faster local compute hides remote waits | Report external latency separately; reduce avoidable round-trips without claiming control of the remote service |
| Infinite search disguised as rigor | Keep unresolved status and a budgeted next experiment; stopping a campaign is not proving a limit |
| Evidence or applicability checks removed for speed | Optimize or amortize valid checks; preserve freshness and effect semantics |

## 15. The final campaign deliverable

A complete first-campaign result contains:

- A reproducible baseline and objective acceptance contract.
- A library of checked work reductions with scope and break-even costs.
- A hardware reference atlas with uncertainty and measurement conditions.
- Qualified native realizations for supported operations, with translation-evidence limits explicit.
- Full-agent cold/warm and held-out results, including failure paths and all offline costs.
- An append-only record of positive and negative experiments.
- A bound ledger separating theorems, hardware capacities, attained references, and assumptions.
- An unresolved-gap list with owners and the next experiment or missing observation.

The claim this earns is specific: **for these objectives, these semantics, and this machine, I have removed the demonstrated unnecessary work and can explain the remaining measured costs to the stated uncertainty.** Where I cannot explain them, the research remains open.

## 16. Research grounding and source register

Research was located through Undermind, with current tool documentation checked through Context7. Full-text sections of the LRAT and speculative-decoding papers were opened; other entries were reviewed through abstracts/metadata or primary documentation. This is a targeted foundation for the project, not an exhaustive literature survey or replication of the papers. Published speedups are not forecasts for AIEN. The recent PreAct result is supporting motivation only; its abstract was reviewed, not its full evaluation.

### GitHub evidence

- **G1 — Native command lists and decode graph:** [decode graph](https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/src/omega_gpu_decode_graph.c), [command lists](https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/src/omega_gpu_cmdlist.c), [Linux platform synchronization](https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/src/omega_gpu_platform_linux.c).
- **G2 — Historical per-kernel timeline:** [graph-on-stamps/stdout](https://github.com/aien-dev/aien-sovereign-core-mv/blob/e6852de85dfe503347d37ed2438d1ce6f1ac8c3a/docs/inference/evidence/own30b-L2-20261013/graph-on-stamps/stdout).
- **G3 — Historical requalification and numerical exceptions:** [NOTES.md](https://github.com/aien-dev/aien-sovereign-core-mv/blob/e6852de85dfe503347d37ed2438d1ce6f1ac8c3a/docs/inference/evidence/own30b-requal-main-20261015/NOTES.md). Whole-prompt check has a documented first-token discrepancy for one case; this is not universal exact parity.
- **G4 — Draft verification feasibility:** [README.md](https://github.com/aien-dev/aien-sovereign-core-mv/blob/e6852de85dfe503347d37ed2438d1ce6f1ac8c3a/docs/inference/evidence/draft-verify-20261012T1500Z/README.md).
- **G5 — Negative prefetch result:** [l2d_prefetch.out](https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/evidence/OWN30B-REQUAL-MAIN-710d438c-20261015/gates/l2d_prefetch.out).
- **G6 — Existing plan reuse:** [rx_plan.h](https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/src/runtime/rx_plan.h), [rx_plan.c](https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/src/runtime/rx_plan.c).
- **G7 — Typed state projection:** [rx_projection.h](https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/src/runtime/rx_projection.h).
- **G8 — Receipt/checker scope:** [one-layer-receipts.md](https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/spec/one-layer-receipts.md), [c2_lrat.c](https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/src/checker2/c2_lrat.c).
- **G9 — Qualification and language status:** [Omega README](https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/README.md), [surface language V0](https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/spec/omega-language-v0.md), [sovereign-core component map](https://github.com/aien-dev/aien-sovereign-core-mv/blob/e6852de85dfe503347d37ed2438d1ce6f1ac8c3a/CONTEXT.md).
- **G10 — Existing FP8 load-pipelining variant:** [omega_blackwell_codegen_moe2.h](https://github.com/aien-dev/omega-mv/blob/f4a9849fb127f8d2d664dfc56890752ad180c507/src/omega_blackwell_codegen_moe2.h). E11 tunes and tests this existing mechanism rather than proposing it as new.

### Research and documentation

- **R1 — Efficient Certified RAT Verification.** Certificate hints can simplify trusted checking; this motivates E02 and E05, not a claim that all verification is cheap. [[Cru16]](https://doi.org/10.1007/978-3-319-63046-5_14)
- **R2 — I/O Complexity: The Red-Blue Pebble Game.** Foundation for algorithm/computation-graph communication analysis. Use a derivation appropriate to the chosen graph and memory model, not a universal transfer bound. [[Hon81]](https://doi.org/10.1145/800076.802486)
- **R3 — egg: Fast and Extensible Equality Saturation.** A practical representation for exploring rewrites and extracting by a cost model. It does not supply soundness for arbitrary user rules or a global-optimality theorem. [[Wil20]](https://doi.org/10.1145/3434304)
- **R4 — Roofline: An Insightful Visual Performance Model for Multicore Architectures.** Framework for relating operational intensity, bandwidth, and compute. [[Wil09]](https://doi.org/10.1145/1498765.1498785)
- **R5 — Fast Inference from Transformers via Speculative Decoding.** Motivation for proposal-plus-target verification and distribution-preserving sampling under its assumptions. [[Lev22]](https://doi.org/10.48550/arXiv.2211.17192)
- **R6 — FlashAttention: Fast and Memory-Efficient Exact Attention with IO-Awareness.** Demonstrates how reformulating data movement changes performance without approximating the mathematical attention operation; floating-point identity requires a separate contract. [[Dao22]](https://doi.org/10.52202/068431-1189)
- **R7 — PreAct: Computer-Using Agents that Get Faster on Repeated Tasks.** Recent motivation for checked reusable workflows; benchmark-specific and not evidence that AIEN's current integration is complete. [[Li26]](https://doi.org/10.48550/arXiv.2606.17929)
- **D1 — NVIDIA Nsight Compute documentation**, accessed via Context7: [profiling guide](https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html), [CLI cache/replay/clock controls](https://docs.nvidia.com/nsight-compute/NsightComputeCli/index.html). Reference methodology only; native-path compatibility remains an experiment.
- **D2 — egg documentation**, accessed via Context7: [Runner and search limits](https://docs.rs/egg/latest/egg/struct.Runner.html), [explanations](https://egraphs-good.github.io/egg/egg/tutorials/_03_explanations/index.html). Explanation traces show rule applications; rules themselves need justified semantics.
- **H1 — NVIDIA DGX Spark hardware specification:** [product specification](https://www.nvidia.com/en-us/products/workstations/dgx-spark/). The 273 GB/s figure is a specification, not a measured AIEN throughput result.

Research workspace: [AIEN — Mathematical Work Reduction and Physical Limits](https://app.undermind.ai/projects/71b4b2d1-0818-4a84-8c00-452e1071922a).
