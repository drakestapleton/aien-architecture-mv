# AIEN Evolution Arena
## From a Resident Intelligent Runtime to a Verifiable Self-Improving Computational System

> Source: research program document supplied by Drake Stapleton, 2026-09-29. Saved as-is;
> the frozen specification derived from it is `docs/specs/EVOLUTION_ARENA_SPEC_V1.md`.

### Purpose

The next major AIEN research program is to connect capabilities that currently exist as separate architectural ideas into one closed empirical loop:

```text
Objective
    ↓
AIEN proposes approaches
    ↓
J-Space forks candidate Worlds
    ↓
OMEGA constructs semantic alternatives
    ↓
FORGE realizes them on available hardware
    ↓
AEGIS verifies admissibility
    ↓
Candidates execute
    ↓
Evidence measures reality
    ↓
Cortex records what happened
    ↓
Evolution Arena compares descendants
    ↓
Independent promotion selects an improvement
    ↓
AIEN resumes with a better verified method
```

This program is called the **Evolution Arena**.

It is not a new master architecture.

It is the mechanism that joins the existing Phase F agency/composition work, Phase G learned search, Phase H Cortex/RSI integration, and eventually Physics Zero.

The central research question is:

> Can AIEN generate competing descendants of part of itself, evaluate them against reality in isolated Worlds, discover an improvement that generalizes, preserve the causal evidence explaining why it improved, and adopt it without allowing the candidate to approve itself?

If the answer can be demonstrated repeatedly on held-out work, AIEN has crossed an important boundary.

---

# 1. Current prerequisite state

As of September 29, 2026, the live repository state provides much of the necessary foundation.

R15 has already demonstrated the resident reaction architecture on the DGX Spark and passed its performance proof.

R16 is still active and must finish removing the remaining central orchestration paths before the Evolution Arena becomes part of the runtime.

The canonical 64-bit effect capability migration has now merged in Omega. That closes an important authority-width defect before more sophisticated autonomous experimentation is added.

FORGE PR #13 is establishing the typed:

```text
OMEGA request
→ FORGE realization
→ AEGIS verification
→ hardware
→ execution evidence
```

boundary.

Omega PR #60 has already demonstrated a primitive form of empirical learning: measured experience can select better realizations than a fixed dispatch rule.

ARGUS is improving, but remains unfinished. Its newer integration measurement is approximately +3.9% R8 wall-clock overhead, below its 5% lane threshold but still above the stricter 2% architectural target, and authority-replay findings remain open.

Therefore the Evolution Arena must not become another runtime loop while R16 and these substrate corrections are still active.

Architecture, data contracts, evaluation protocols and candidate formats can begin immediately.

Runtime activation comes after the foundation gates close.

---

# 2. The fundamental rule

AIEN will initially be allowed to improve **methods**, not arbitrary authority-bearing code.

That distinction is important.

The first evolutionary surfaces should be:

```text
OMEGA transformation strategies
OMEGA realization-selection policies
FORGE realization plans
J-Space search policies
J-Space branch widths
Skill procedures
memory retrieval strategies
cache/layout policies
routing strategies
cost models
abstractions discovered by Omega
```

Later generations may include:

```text
generated algorithms
generated native realizations
learned search guides
small model components
compiler components
runtime components
eventually AIEN descendants
```

Authority mechanisms, AEGIS verification policy, promotion authority and the trusted boot chain are not early mutation targets.

The system earns wider self-modification only by first demonstrating that the narrower mechanism is trustworthy.

---

# 3. The Candidate object

Everything begins with a first-class immutable **Candidate**.

A candidate is not simply a source-code patch.

It is an experimental descendant.

Conceptually:

```text
Candidate {
    candidate_id
    parent_candidate_ids[]
    lineage_root
    mutation_class
    objective_digest

    artifact_digest
    semantic_digest
    configuration_digest

    proposed_by
    creation_generation

    required_capabilities[]
    resource_limits

    verifier_results[]
    experiment_ids[]
    evidence_root

    status
}
```

Candidate identity must be content-addressed.

Parentage must be permanent.

A candidate cannot rewrite its history after seeing evaluation results.

The lifecycle is:

```text
PROPOSED
   ↓
REALIZED
   ↓
VERIFIED
   ↓
EVALUATING
   ↓
EVALUATED
   ↓
ELIGIBLE
  ↙       ↘
ARCHIVED   PROMOTED
```

Failure at any stage remains evidence.

A failed lineage must not disappear merely because another candidate succeeded.

That is essential because AIEN must eventually learn not only what worked, but what kinds of transformations repeatedly fail.

---

# 4. EA0 — Freeze the experimental constitution

Before implementing evolution, specify what counts as improvement.

This is the most important step.

Every experiment class needs a frozen contract defining:

```text
objective
allowed mutation surface
training workloads
validation workloads
sealed holdout workloads
quality requirements
performance metrics
resource limits
authority limits
maximum experimental budget
failure conditions
promotion threshold
rollback condition
```

The evaluator must exist conceptually before the candidate sees the hidden evaluation.

Otherwise the system can optimize the test rather than improve the capability.

The first Evolution Arena should therefore use pre-registered workloads and committed holdout seeds.

Exit gate:

> AIEN cannot change the definition of success after generating candidates.

---

# 5. EA1 — Build lineage and candidate storage

Create a content-addressed candidate graph.

Conceptually:

```text
                    C0
                /   |   \
              C1    C2    C3
             / \          |
           C4  C5         C6
               |
              C7
```

Each edge means:

```text
parent
+
specific transformation
=
descendant
```

The graph records:

```text
what changed
why it was proposed
which evidence motivated it
what verification said
how it performed
why it survived
why it was rejected
```

Cortex eventually retains higher-level knowledge extracted from this graph.

The immutable candidate/evidence graph remains the ground truth.

Exit gate:

> Every candidate's ancestry and experimental history can be reconstructed byte-for-byte.

---

# 6. EA2 — Typed mutation operators

Do not begin with unrestricted source-code rewriting.

Begin with transformations that AIEN can name and reason about.

For example:

```text
CHANGE_TILE_SIZE
CHANGE_UNROLL_FACTOR
CHANGE_REALIZATION
CHANGE_MEMORY_LAYOUT
CHANGE_SEARCH_WIDTH
CHANGE_SEARCH_HEURISTIC
REORDER_TRANSFORMATIONS
SPECIALIZE_FOR_SHAPE
FUSE_OPERATIONS
SPLIT_OPERATION
CHANGE_CACHE_POLICY
ALTER_COST_MODEL
INTRODUCE_ABSTRACTION
RETIRE_ABSTRACTION
```

OMEGA should express these as semantic transformations wherever possible.

That gives AIEN something far more useful than arbitrary textual mutation.

It can eventually learn:

> Under these machine conditions and semantic structures, this class of transformation tends to improve cost.

That becomes reusable knowledge.

Later, AIEN can synthesize new mutation operators themselves.

But the first generation should be enumerable and auditable.

---

# 7. EA3 — J-Space becomes the experimental arena

J-Space provides the isolation mechanism.

Suppose AIEN has a current method `C0`.

It proposes four alternatives:

```text
World 0 → C0 control
World 1 → C1
World 2 → C2
World 3 → C3
World 4 → C4
```

Each World begins from the same committed state.

Candidates perform reversible work inside their World.

The Worlds cannot commit external effects merely because a candidate asks them to.

The evaluator records separate dimensions:

```text
semantic correctness
latency
throughput
energy
memory
verification cost
synthesis cost
transfer cost
failure rate
uncertainty
robustness
generalization
```

Do not immediately collapse these into one scalar "fitness."

Preserve the dimensions.

J-Space can then identify a Pareto frontier.

For example:

```text
Candidate A
fastest, high energy

Candidate B
slightly slower, extremely efficient

Candidate C
best under memory pressure

Candidate D
best generalization

Candidate E
invalid
```

The correct realization can therefore depend on the problem and machine state rather than there being one universal winner.

---

# 8. EA4 — Make evidence the learning signal

Every experiment emits an immutable evidence package.

A useful evidence object should bind:

```text
candidate identity
parent identity
experiment contract
machine identity
hardware/substrate identity
World identity
input/workload identity
realization identity
verification result
measured output
latency
energy
memory
thermal/load conditions
errors
faults
result digest
environment digest
```

Evidence is what teaches the system.

Not prose.

Not model confidence.

Not the candidate's explanation.

Measured evidence.

This preserves the project's core doctrine:

```text
EVIDENCE TEACHES.
```

---

# 9. EA5 — Cortex becomes the scientist's notebook

Cortex should not simply ingest candidate logs.

It should extract claims from experiments.

For example:

```text
CLAIM:
quad4 tends to outperform scalar matvec
on X925 cores for wide-N workloads.

SUPPORT:
experiments E14, E19, E22, E31

COUNTEREVIDENCE:
E41 under memory pressure

CONFIDENCE:
high under envelope A
low outside envelope A
```

Another memory might be:

```text
HYPOTHESIS:
operation fusion becomes beneficial
when synchronization cost exceeds
the additional register-pressure penalty.
```

This creates several memory classes:

```text
episode
observation
claim
hypothesis
procedure
abstraction
counterexample
operating envelope
```

Cortex should also learn when to forget or demote knowledge.

A once-good optimization may become false after:

```text
new hardware
new firmware
different thermal regime
different model
different workload distribution
new realization backend
```

So memories require validity envelopes and contradictory evidence.

This is how Cortex becomes epistemic memory rather than persistent RAG.

---

# 10. EA6 — Build the AIEN self-model

Now give AIEN an explicit model of its own computational body.

Call it the **Machine Self-Model** conceptually; it does not necessarily require a new named subsystem.

It contains beliefs such as:

```text
Machine 1
    CPU availability
    CPU classes
    GPU availability
    memory pressure
    resident allocations
    thermal state
    queue pressure
    known realization costs
    current calibration quality
    network topology
    available Machines
    degraded components

Model state
    inference latency
    KV pressure
    context demand

World state
    active branches
    resource commitments

Epistemic state
    uncertain cost predictions
    stale evidence
    conflicting measurements
```

Most importantly, uncertainty must be represented.

AIEN should be able to recognize:

> I do not know which realization is better under this condition.

That uncertainty can itself trigger an experiment.

This turns optimization from:

```text
pick the predicted winner
```

into:

```text
pick the winner
OR
run the experiment whose result would be most valuable.
```

That is the bridge toward active scientific reasoning.

---

# 11. EA7 — Connect the empirical Omega optimizer

The existing Omega empirical cost model is a seed for this.

Today it learns among CPU matvec arms.

The next generations should widen along two axes.

First, more semantic operations:

```text
matvec
matmul
reductions
tensor operations
memory transformations
fused graphs
```

Then more realization domains:

```text
Grace CPU
Blackwell GPU
different Blackwell realizations
later analog
later remote Machine
```

Eventually Omega's decision becomes:

```text
semantic operation
+
required accuracy
+
current machine state
+
available substrates
+
historical evidence
+
uncertainty
=
realization decision
```

This is considerably more interesting than a static compiler.

The compiler continuously learns the physics of the machine it inhabits.

---

# 12. EA8 — Independent promotion

This boundary must remain uncompromising.

The component creating a candidate never grants that candidate production authority.

The sequence is:

```text
AIEN / RSI
proposes Candidate C17
        ↓
isolated Worlds evaluate C17
        ↓
OMEGA verifies semantics
        ↓
AEGIS verifies invariants
        ↓
sealed evaluator grades holdout
        ↓
promotion request created
        ↓
independent promotion authority
        ↓
R9 generation barrier
        ↓
atomic generation switch
```

Candidate code cannot:

```text
mint promotion authority
change the holdout
change the threshold
edit previous evidence
promote itself
remove the previous generation
disable rollback
```

After promotion, the old generation remains recoverable.

A crash during promotion must produce:

```text
OLD
or
NEW
```

never a hybrid state.

This is the distinction between self-improvement and uncontrolled self-replacement.

---

# 13. EA9 — The first flagship experiment

The first experiment should not try to evolve the entire AIEN system.

It should prove the mechanism.

Use a family of numerical operations where Omega already has strong semantic oracles and physical CPU/GPU realizations.

A suitable initial target is:

```text
matrix/vector and small matrix/tensor computation families
```

The experiment begins with a human-supplied baseline set of realization strategies.

Freeze:

```text
training shapes
validation shapes
hidden held-out shapes
correctness bounds
maximum search budget
performance measurements
promotion threshold
```

Then let the system run.

AIEN sees an objective such as:

```text
Improve execution cost across this workload family
without changing semantic results,
without exceeding the energy envelope,
and without sacrificing held-out performance.
```

The system then:

```text
1. Creates baseline World.

2. Generates descendants using typed transformations.

3. OMEGA constructs candidate realizations.

4. AEGIS rejects invalid candidates.

5. FORGE runs valid candidates on Grace/Blackwell.

6. Evidence captures actual performance.

7. Cortex learns patterns and counterexamples.

8. J-Space allocates more search toward promising lineages.

9. Poor descendants are archived.

10. Promising descendants generate children.

11. Evaluation is frozen.

12. The best eligible candidate is tested on the sealed holdout.

13. Independent authority either promotes it or refuses it.

14. The machine restarts.

15. The promoted strategy is reconstructed from durable state.

16. Held-out transfer is tested again.

17. AIEN receives a related but previously unseen workload.

18. The experiment asks whether the learned abstractions reduce search effort there.
```

That last step matters enormously.

Merely optimizing one benchmark is autotuning.

Discovering reusable structure that accelerates a different held-out problem is learning.

---

# 14. The flagship success criteria

The experiment is successful only if all of these are true:

```text
Semantic correctness preserved.

Candidate lineage fully reconstructible.

No invalid candidate executed outside its allowed World.

No candidate self-promoted.

No evaluation criterion changed after candidate generation.

At least one descendant improves the frozen objective.

The improvement survives sealed holdout evaluation.

The promoted generation survives restart.

Rollback to the previous generation works.

Cortex can identify evidence supporting the improvement.

The learned method or abstraction reduces search cost
on a related unseen task.

All claimed physical measurements are tied to actual hardware evidence.
```

If the system merely generates a faster kernel, I have an autotuner.

If it satisfies the entire sequence, I have demonstrated something much closer to bounded empirical self-improvement.

---

# 15. EA10 — Add analog and heterogeneous evolution

Once the digital experiment works, analog becomes much more meaningful.

The evolutionary population can contain:

```text
C31 — Grace realization
C32 — Blackwell SIMT
C33 — Blackwell Tensor Core
C34 — analog realization
C35 — CPU + GPU hybrid
C36 — remote Machine realization
```

All share one Omega semantic contract.

Their evidence differs.

For analog:

```text
accuracy distribution
calibration
noise
drift
conversion cost
energy
temperature envelope
```

become part of evaluation.

The Evolution Arena does not need special philosophical rules for analog.

It simply gains a radically different physical search space.

That is precisely why the substrate-neutral FORGE work matters.

---

# 16. EA11 — Move from optimization to invention

Once the system reliably improves known strategies, widen the mutation surface.

Stage one:

```text
choose parameters
```

Stage two:

```text
recombine known transformations
```

Stage three:

```text
discover new transformation sequences
```

Stage four:

```text
propose reusable Omega abstractions
```

Stage five:

```text
propose new algorithms
```

Stage six:

```text
propose new Skills and reasoning procedures
```

Stage seven:

```text
propose changes to limited parts of its own implementation
```

Each expansion requires a separate qualification gate.

AIEN should earn access to larger mutation surfaces.

---

# 17. EA12 — Evolve search itself

Eventually the Arena should permit descendants of the search policy.

Suppose the existing J-Space policy uses:

```text
branch width = 8
depth = 4
heuristic H1
prune rule P1
```

A candidate might propose:

```text
branch width = adaptive
depth = uncertainty-dependent
heuristic = learned H7
prune rule = Pareto dominance + novelty
```

Those policies can themselves compete.

The important recursive relation becomes:

```text
search discovers algorithms

and

search discovers better ways to search.
```

But the outer evaluation and promotion boundary remains independent.

That is where recursive improvement becomes manageable.

---

# 18. EA13 — Evolutionary diversity and the archive

Do not keep only the current winner.

Maintain an archive.

Why?

Because environments change.

Candidate A might be excellent on Blackwell.

Candidate B might be excellent under low energy.

Candidate C might handle unusual tensor shapes.

Candidate D might be slower but exceptionally robust.

Candidate E might contain an abstraction useful to a future lineage.

The archive should therefore preserve novelty as well as current fitness.

Conceptually:

```text
ACTIVE GENERATION
       │
       ├── champion
       │
       └── known-good fallback

EVOLUTION ARCHIVE
       ├── high-speed lineage
       ├── low-energy lineage
       ├── low-memory lineage
       ├── robustness lineage
       └── unusual/novel lineage
```

This prevents premature convergence.

It also lets future AIEN instances revisit previously unhelpful ideas when machine conditions change.

---

# 19. EA14 — Counterfactual learning

One of the most valuable capabilities will be learning from branches that were never committed.

J-Space naturally provides this.

Suppose four strategies were tested and C3 won.

The committed World uses C3.

But Cortex retains:

```text
C1 was slower because...
C2 failed under...
C4 was better only when...
```

Those unchosen Worlds are counterfactual experience.

Most agents throw that information away.

AIEN should not.

This creates an unusually rich learning substrate:

```text
actual history
+
rejected alternatives
+
failed hypotheses
+
near misses
+
counterfactual outcomes
```

That could become one of the project's strongest research advantages.

---

# 20. EA15 — From optimization to scientific discovery

Once the experiment mechanism is mature, Physics Zero becomes a natural extension.

The same machinery changes from:

```text
Which realization is faster?
```

to:

```text
Which hypothesis about this unknown system is true?
```

Then:

```text
Observation
    ↓
Candidate theories
    ↓
J-Space branches
    ↓
Each theory predicts outcomes
    ↓
AIEN asks which experiment best separates the theories
    ↓
AEGIS bounds the intervention
    ↓
FORGE realizes the experiment
    ↓
Physical observation
    ↓
Evidence
    ↓
Cortex updates theory confidence
    ↓
repeat
```

The evolutionary archive contains theories instead of compiler strategies.

The fundamental machinery is the same.

That is why building the Evolution Arena first has enormous leverage.

---

# 21. External scientific proving ground

AIEN should have a separate benchmark repository dedicated to falsifying its major claims.

Not documentation examples.

Not tests written only to validate expected behavior.

A real experimental suite.

Each major claim receives an ablation:

```text
AIEN vs fixed realization selection

J-Space vs single trajectory

Cortex vs ordinary retrieval

Evolution Arena vs conventional autotuning

learned search vs fixed search

proof-carrying promotion vs unrestricted update

multi-substrate Omega vs fixed-device compiler

counterfactual memory vs committed-history-only memory
```

Every experiment publishes:

```text
pre-registration
candidate commit
environment
raw measurements
failures
sealed evaluation
final receipt
reproduction command
```

Failed experiments remain public artifacts.

This matters because the system's credibility will ultimately come from experiments that other people can rerun.

---

# 22. Execution order

The practical sequence should be:

```text
NOW
│
├─ Finish R16
│  No new central orchestration remains.
│
├─ Finish FORGE v1 qualification
│  Stable Omega → Forge → AEGIS → hardware boundary.
│
├─ Close capability/authority defects
│  Effect cap64 is merged; finish authority-instance/replay work.
│
├─ Finish ARGUS-0
│  Correctness + accepted performance contract.
│
├─ Merge/normalize Omega empirical optimizer
│
▼
EVOLUTION ARENA FOUNDATION
│
├─ EA0 frozen evaluation protocol
├─ EA1 Candidate + lineage objects
├─ EA2 typed mutation operators
├─ EA3 J-Space experimental Worlds
├─ EA4 evidence schema
├─ EA5 Cortex experimental memory
├─ EA6 machine self-model
├─ EA7 Omega empirical selection integration
└─ EA8 independent promotion integration
│
▼
FLAGSHIP EXPERIMENT
│
├─ CPU realization population
├─ Blackwell realization population
├─ evolutionary search
├─ sealed holdout
├─ promotion
├─ reboot/recovery
└─ transfer to unseen problem
│
▼
HETEROGENEOUS EXPANSION
│
├─ substrate-neutral FORGE v2
├─ analog simulation
├─ physical analog
├─ Fabric Machines
└─ heterogeneous evolutionary populations
│
▼
OPEN-ENDED IMPROVEMENT
│
├─ new abstractions
├─ new algorithms
├─ search-policy evolution
├─ Skill evolution
└─ bounded implementation evolution
│
▼
PHYSICS ZERO
│
└─ theories and experiments become evolutionary objects
```

---

# 23. Parallel implementation lanes

Once R16 is complete, this can be developed without putting everyone in the same files.

**Lane A — Candidate & Lineage**

Own the immutable candidate schema, content addressing, lineage graph and archive.

**Lane B — J-Space Arena**

Own World fork/evaluate/prune mechanics and counterfactual retention.

**Lane C — Omega Evolution**

Own typed mutation operators, realization candidate generation and empirical selection.

**Lane D — Cortex Epistemics**

Own experiment ingestion, claims, hypotheses, counterexamples, confidence and abstraction memories.

**Lane E — Evaluation & Sealed Holdout**

Own preregistration, hidden workloads, metrics, grading and reproducibility.

**Lane F — Promotion & Authority**

Own R9 integration, promotion isolation, rollback and attempted-self-promotion tests.

**Lane G — Machine Self-Model**

Own resource state, measured capability state, cost uncertainty and experiment-trigger signals.

**Lane H — Grand Challenge**

Own independent benchmark harnesses and ablations rather than production implementation.

An integration owner controls shared schemas.

No two lanes should independently invent Candidate, Evidence or World identity.

---

# 24. The first concrete deliverable

The next research artifact after the current foundation closes should be:

```text
EVOLUTION_ARENA_SPEC_V1.md
```

It should freeze only five things:

```text
Candidate object
Lineage model
Evaluation contract
Promotion contract
First flagship experiment
```

Do not implement every future idea in that specification.

Then build:

```text
EA0 — candidate identity / lineage
EA1 — isolated evaluation Worlds
EA2 — typed Omega mutations
EA3 — empirical measurement
EA4 — sealed holdout
EA5 — independent promotion
EA6 — restart + transfer proof
```

That is enough to establish the core scientific claim.

---

# 25. What the first public demonstration should look like

A person starts with a clean AIEN installation.

The baseline system contains several known implementations of a workload family.

The operator gives one instruction:

> Improve this capability within the declared correctness, energy and resource constraints.

Then the system runs.

The observer can watch the lineage tree grow.

Some candidates fail verification.

Some execute but regress.

Some specialize too aggressively and fail validation.

One lineage discovers a useful transformation.

Descendants refine it.

The winning candidate passes the sealed holdout.

AIEN itself does not possess promotion authority.

The independent gate promotes the new generation.

The machine is restarted.

The improved method survives.

Then a new, related workload is introduced.

The retained abstraction reduces the amount of search required to solve it.

The final report includes the entire causal chain from the original objective through every ancestor, experiment, rejection, promotion receipt and held-out measurement.

No step requires trusting AIEN's own statement that it improved.

The evidence demonstrates it.

---

# 26. Long-term destination

The mature system becomes:

```text
AIEN
does not contain one fixed intelligence strategy.

It contains a verified ecology of evolving strategies.

OMEGA
does not contain one fixed compiler.

It learns how meaning should be realized
on the physical world currently available.

Cortex
does not merely remember previous conversations.

It accumulates experimentally grounded knowledge
about problems, machines, strategies and itself.

J-Space
does not merely generate alternative answers.

It becomes the laboratory in which unrealized futures
can be tested before one becomes reality.

FORGE
does not target one processor.

It gives semantic programs physical form
across whatever computational substrates exist.

AEGIS
does not decide what intelligence should believe.

It protects the boundary between proposals
and authorized reality.

RSI
does not edit production.

It produces descendants and evidence.

ARGUS
does not grant authority.

It observes whether the resulting organism
continues to respect its declared invariants.
```

The resulting system is not simply an agent, compiler, operating system, model runtime or self-improving program.

It is a persistent experimental computational organism in which proposals, alternatives, physical realization, evidence, learning and improvement are all first-class state—and in which no component is permitted to declare its own success.
