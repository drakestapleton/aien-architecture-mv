> **SUPERSEDED / HISTORICAL — DO NOT USE AS AN ACTIVE IMPLEMENTATION PLAN**
>
> Original path: `docs/14-master-architectural-plan.md`
>
> Archived on 2026-09-27 during plan consolidation. The active cross-project execution plan is [CURRENT_EXECUTION_PLAN.md](../../../../CURRENT_EXECUTION_PLAN.md), governed by [PLAN_AUTHORITY.md](../../../../PLAN_AUTHORITY.md).
>
> Retained for provenance only.

---

# AIEN Master Architectural Plan

## 1. North Star

AIEN exists to reduce the distance between human intention and physical reality.

The ultimate system should allow a person to describe a desired outcome, then have AIEN determine what must change, what it is permitted to change, how that change can be accomplished, which physical realization is appropriate, whether the result actually occurred, and what can be learned from it.

The long-term execution path is:

```text
Human Intent
     ↓
Desired State
     ↓
Formal Transformation
     ↓
Constraints + Authority
     ↓
Candidate Futures
     ↓
Verification + Evaluation
     ↓
Authorization
     ↓
Physical Realization
     ↓
Physics
     ↓
Observed Reality
     ↓
Evidence
     ↓
Memory + Improvement
```

The concise definition is:

> **AIEN compiles desired state into authorized, verified physical transformation.**

The completed system is not fundamentally an operating system, AI model, programming language, CPU architecture, or robot.

Those are components and physical realizations.

---

## 2. The Permanent Architectural Rule

No implementation layer below intent should become the permanent definition of AIEN.

Therefore:

```text
Rust        != AIEN
AArch64     != AIEN
x86         != AIEN
RISC-V      != AIEN
binary      != AIEN
CUDA        != AIEN
NVIDIA      != AIEN
Linux       != AIEN
a model     != AIEN
a CPU       != AIEN
```

Today AIEN is implemented primarily through Rust and AArch64 because those are useful engineering choices.

They are not the final abstraction.

The durable object should eventually describe:

```text
What should become true?
What transformation produces it?
What constraints apply?
What authority is required?
What evidence proves success?
```

Everything below that may evolve.

---

## 3. The Seven-Layer Architecture

The whole system can be understood as seven architectural layers.

```text
┌──────────────────────────────────────┐
│ 7. HUMAN INTENT                      │
│    "What do I want?"                 │
├──────────────────────────────────────┤
│ 6. SEMANTIC / DESIRED STATE          │
│    "What exactly must become true?"  │
├──────────────────────────────────────┤
│ 5. INTELLIGENCE                      │
│    Agent, Cortex, J-Space, Skills    │
├──────────────────────────────────────┤
│ 4. AUTHORITY                         │
│    Capabilities, AEGIS, Effects      │
├──────────────────────────────────────┤
│ 3. TRANSFORMATION                    │
│    Artifact IR, Transformation IR    │
├──────────────────────────────────────┤
│ 2. PHYSICAL COMPILATION              │
│    Physical Compiler + Fabric        │
├──────────────────────────────────────┤
│ 1. PHYSICAL SUBSTRATE                │
│    CPU/GPU/FPGA/waves/analog/etc.    │
└──────────────────────────────────────┘
                ↓
             PHYSICS
```

Each layer has one job.

No layer should secretly absorb the responsibilities of another.

---

## 4. Layer 1: The Trusted Physical Substrate

This is what AIENOS is currently establishing.

Its job is not intelligence.

Its job is control.

The kernel must provide deterministic mechanisms for:

```text
boot
memory ownership
address spaces
tasks
scheduling
interrupts
IPC
capabilities
device ownership
DMA confinement
storage
networking
time
recovery
```

The model is never the kernel.

The kernel must continue functioning with no model loaded.

Its fundamental guarantee is:

> A component can affect only the memory, objects and devices for which it has explicit authority.

The trusted base should remain small, inspectable and recoverable.

### Current engineering anchor

The current development line is closing the M3 enforcement substrate:

```text
EL1 kernel
↓
AIENOS-owned MMU
↓
interrupt ownership
↓
preemptive scheduler
↓
EL0 isolation
↓
capability tables
↓
typed IPC
↓
SMMUv3 DMA confinement
↓
device authority
```

This layer must become trustworthy before significant generated native code is admitted.

---

## 5. Layer 2: The Physical Fabric

Above individual drivers sits the abstraction AIEN uses to understand its body.

A Machine should not simply be described as:

```text
"NVIDIA DGX Spark"
```

It should expose capabilities.

Conceptually:

```text
PhysicalCapabilities {
    compute
    memory
    storage
    communication
    devices
    timing
    precision
    topology
    energy
    temperature
    reconfiguration
    failure_properties
}
```

Upper AIEN layers should increasingly ask:

```text
Who can perform this transformation?
```

rather than:

```text
Where is the NVIDIA GPU?
```

The same abstraction can eventually represent:

```text
CPU
GPU
FPGA
specialized accelerator
another Machine
wave network
analog array
optical device
future computing substrate
```

Machine 1 is the first physical body.

It is not AIEN's permanent body.

---

## 6. Layer 3: Canonical Executable Artifacts

Before AIEN becomes hardware-neutral, it needs a clean executable identity system.

This is the bridge between today's software and tomorrow's Transformation IR.

### Binary Artifact

An AIEN Artifact should describe:

```text
identity
exact executable bytes
ABI version
target
resource requirements
requested capabilities
declared effects
ancestry
evidence
admission
```

The central invariant is:

```text
tested bytes
    ==
evaluated bytes
    ==
authorized bytes
    ==
executed bytes
```

The source code that produced an artifact is important provenance.

It is not the executable identity.

Artifacts are:

```text
immutable
content-addressed
versioned
signed where appropriate
reproducibly evaluated
```

This becomes the basis for AIEN Generations.

---

## 7. Generations and Self-Construction

AIEN should grow through explicit Generations.

```text
Generation 0
     ↓
Generation 1
     ↓
Generation 2
     ↓
Generation N
```

An agent may propose a new Generation.

It may not authorize it.

The pipeline is:

```text
Observe
  ↓
Propose
  ↓
Build
  ↓
Verify
  ↓
Isolated test
  ↓
Benchmark
  ↓
J-Space comparison
  ↓
AEGIS admission
  ↓
Canary
  ↓
Promote
```

Failure results in:

```text
quarantine
↓
rollback
↓
preserve evidence
↓
diagnose separately
```

The governing rule is:

> **Rollback first, repair second.**

AIEN never rewrites its trusted running kernel merely because a model believes an improvement is good.

---

## 8. Layer 4: Authority

The most important distinction in AIEN is:

```text
intelligence
≠
authority
```

The model may understand what should happen.

That does not mean it has permission to make it happen.

The canonical effect path is:

```text
Agent
  ↓ proposes
EffectIntent
  ↓
Capability check
  ↓
AEGIS
  ↓
Effect Broker
  ↓
Kernel / driver
  ↓
physical effect
```

### Capabilities

Authority should be explicit and scoped.

Examples:

```text
audio.output
network.local
storage.project.read
device.camera.capture
mail.send
fabric.compute
world.promote
physical.motor.move
```

A capability answers:

```text
WHO
may do WHAT
to WHICH resource
under WHICH bounds
```

No ambient root authority.

---

## 9. AEGIS

AEGIS is the authority boundary between intelligence and reality.

Its job is to determine whether a proposed effect is permitted.

It should understand:

```text
principal
capability
scope
effect type
reversibility
resource bounds
operator policy
risk
provenance
```

Broadly:

```text
reversible internal change
        ↓
can often proceed autonomously

irreversible/external effect
        ↓
requires stronger authority
```

At the deepest future level, AEGIS still exists.

If AIEN is configuring actual physical circuits, waves, power systems or machines, those are effects too.

The Physical Compiler never gets to bypass AEGIS.

---

## 10. Worlds

A World is AIEN's reversible execution state.

It answers:

> "What if we did this?"

A World allows AIEN to modify:

```text
files
configuration
process state
candidate artifacts
runtime state
plans
```

without immediately changing canonical reality.

Conceptually:

```text
Canonical World
     │
     ├── Candidate World A
     ├── Candidate World B
     └── Candidate World C
```

Dropping a World discards it.

Promoting a World requires authority.

This separation lets AIEN explore aggressively while remaining conservative about external effects.

---

## 11. J-Space

J-Space is where AIEN compares possible futures.

It does not perform irreversible actions.

It considers alternatives such as:

```text
implementation A
implementation B
implementation C

plan A
plan B
plan C

physical realization A
physical realization B
physical realization C
```

and evaluates them using evidence.

Eventually:

```text
CPU implementation
GPU implementation
FPGA circuit
wave realization
analog realization
```

could all compete inside J-Space for the same Transformation.

J-Space selects.

OMEGA formalizes.

PHYSICS lowers.

AEGIS verifies.

The Effect Broker adapter executes.

Those remain separate jobs.

---

## 12. Cortex

Cortex is AIEN's durable epistemic memory.

It should remember more than text.

It records:

```text
observations
facts
hypotheses
contradictions
decisions
experiments
provenance
measurements
failures
successful realizations
```

Cortex must preserve the distinction between:

```text
observed
verified
inferred
hypothesized
decided
```

because AIEN must never turn its own previous speculation into "fact" simply because it remembered it.

In the distant Physical Compiler architecture, Cortex also remembers:

```text
transformation
substrate
realization
latency
energy
precision
temperature
failure rate
```

That turns physical experience into reusable knowledge.

---

## 13. The Persistent Agent

The agent is the human-facing continuity layer.

Models may change.

Kernels may change.

Inference state may disappear.

Machines may change.

The logical agent should persist.

```text
persistent identity
persistent history
persistent Cortex
persistent goals
persistent provenance
        ↓
replaceable model
replaceable runtime
replaceable hardware
```

The guiding principle is:

> Losing physical inference state costs computation, not identity.

Power cycle should eventually be ordinary:

```text
power on
↓
AIEN resumes
↓
work
↓
power off
↓
power on
↓
continue
```

---

## 14. Intent and Desired State

The mature AIEN interface should move beyond commands.

Instead of requiring:

```text
open program
click menu
set field
run command
```

the person should increasingly be able to describe:

```text
what they want to become true
```

Example:

```text
"I want this room quieter,
cooler and more energy efficient."
```

The Intent layer transforms this into something closer to:

```text
DesiredState {
    temperature = target range
    acoustic_level <= threshold
    energy = minimize
}
```

The system must distinguish:

```text
hard constraints
soft preferences
unknowns
required permissions
success conditions
```

AIEN should ask when consequential ambiguity cannot safely be resolved.

---

## 15. Transformation IR

This is the major transition beyond traditional computing.

Instead of defining a computation as:

```text
these AArch64 instructions
```

AIEN eventually defines:

```text
Transformation {
    inputs
    outputs
    semantic relation
    invariants
    precision
    permitted error
    latency constraint
    memory constraint
    energy objective
    authority
    effects
}
```

For example:

```text
Y = X × W

dtype = BF16
error <= E
latency <= 2 ms
memory <= M
```

The same Transformation could be realized through multiple physical methods.

That is where AIEN stops being fundamentally ISA-bound.

---

## 16. The Physical Compiler

The Physical Compiler answers:

> **How should this Transformation become physical on the resources currently available?**

Initially it will perform ordinary decisions:

```text
scalar CPU
vs
vector CPU
vs
accelerator
```

Later:

```text
CPU
GPU
FPGA
distributed Machine
```

And eventually:

```text
digital circuit
multi-valued circuit
wave network
analog system
optical realization
other physical substrate
```

The compiler does not automatically select "fastest."

It selects according to the Transformation's actual objective:

```text
correctness
latency
energy
memory
precision
temperature
reliability
privacy
availability
```

---

## 17. Physical IR

Below Transformation IR may eventually sit a representation of physical computation.

For conventional digital systems, Physical IR could describe:

```text
logic elements
registers
memory
connections
timing
resource constraints
```

For future substrates it may describe more general physical relationships.

The crucial design principle is:

> Physical IR describes a realization, not AIEN's permanent semantics.

A new substrate can therefore introduce another backend without redefining AIEN.

---

## 18. The Hum of the Hive

Wave-based computation is a future Physical Fabric backend, not the definition of AIEN itself.

A Wave IR might describe:

```text
oscillator
frequency
amplitude
phase
coupling
modulation
interference
resonance
measurement
```

Instead of computing only through:

```text
LOAD
ADD
STORE
BRANCH
```

a physical realization might compute through:

```text
couple
oscillate
shift
interfere
resonate
settle
observe
```

The collective physical state can be thought of as:

> **The Hum of the Hive.**

Conceptually:

```text
HiveState {
    spectrum
    phase_map
    synchronization
    energy_distribution
    resonance_modes
    stability
}
```

The Hum is not mystical.

It is the measurable dynamical physical state of the computational fabric.

Wave computation should begin as simulation, then only move onto real experimental hardware after deterministic security and measurement infrastructure exist.

---

## 19. Multi-Valued and Analog Computing

Binary remains the immediate implementation substrate.

AIEN should not assume it is eternally optimal.

Future research lanes may test:

```text
binary
ternary
balanced ternary
higher radix
continuous analog
timing-based computation
frequency-domain computation
optical systems
neuromorphic systems
```

No representation wins because it sounds elegant.

It must demonstrate value through measured workloads.

AIEN's architecture therefore remains:

```text
representation-independent
```

rather than:

```text
binary-first forever
```

or:

```text
wave-first forever
```

---

## 20. Physical Reality

At sufficient maturity, AIEN's transformations may extend beyond computation.

Physical effects could include:

```text
configure
transmit
move
heat
cool
emit
energize
manufacture
route
assemble
```

through properly authorized devices.

That creates the full loop:

```text
Desired State
      ↓
Act
      ↓
Measure
      ↓
Compare
      ↓
Act again
```

AIEN does not simply assume an issued command succeeded.

Reality must be measured.

---

## 21. Provenance

Every consequential transformation should create evidence.

AIEN should be able to answer:

```text
What was requested?
Who requested it?
What interpretation was used?
Which transformation was selected?
Which alternatives were considered?
What authority allowed it?
What artifact executed?
On what Machine?
What physical resources were used?
What actually happened?
What evidence supports that claim?
```

This provenance layer connects the entire system.

Without it, autonomous self-improvement becomes storytelling.

With it, improvements can be tested.

---

## 22. RSI

RSI is AIEN's improvement engine.

It may propose improvements to:

```text
algorithms
scheduler policies
memory placement
kernel implementations
cache policy
inference kernels
Transformation lowering
physical backend selection
circuit topology
wave configuration
physical placement
```

But RSI is never its own authority.

The loop remains:

```text
observe
↓
hypothesize
↓
construct candidate
↓
evaluate
↓
compare
↓
authorize
↓
promote
```

A failed candidate is evidence, not permission to try uncontrolled live mutations.

---

## 23. Fabric and Multiple Machines

AIEN should appear as one logical system even when it occupies several Machines.

```text
                 AIEN
                  │
       ┌──────────┼──────────┐
       ↓          ↓          ↓
   Machine 1  Machine 2  Machine N
```

Fabric owns:

```text
machine identity
capability advertisement
placement
topology
communication
leases
failover
resource scheduling
```

Fabric does not decide semantic goals.

J-Space and the runtime decide what needs to happen.

Fabric determines where eligible work can run.

---

## 24. The Bootstrap Boundary

AIEN cannot magically wake on arbitrary matter.

Every new substrate needs a minimal physical entry point.

A substrate must expose enough capability for AIEN to:

```text
begin execution
represent state
change state
observe state
communicate
recover/reset
```

The architecture should minimize the substrate-specific seed.

Conceptually:

```text
New hardware
    ↓
Bootstrap Seed
    ↓
Physical Fabric Adapter
    ↓
Physical Capability Graph
    ↓
AIEN
```

Over time AIEN should be able to generate increasing portions of its own optimized backend after bootstrapping through a simple generic one.

This is the route to true hardware portability.

---

## 25. Self-Hosting

AIEN reaches a deeper form of independence when it can reconstruct itself.

Starting from:

```text
minimal trusted Seed
+
canonical artifacts
+
supported physical substrate
```

AIEN should eventually be able to rebuild:

```text
runtime
verifier
AEGIS
Cortex
Physical Compiler
backend
agent environment
```

and establish a new Generation.

Self-hosting does not mean uncontrolled self-modification.

It means the system can reproduce itself through the same verified admission process applied to everything else.

---

## 26. The Four Eras

The entire project can be reduced to four large eras.

### Era I: AIEN Owns a Computer

Build:

```text
AIENOS
kernel isolation
capabilities
devices
storage
networking
native inference
Cortex
persistent agent
```

Outcome:

> AIEN can safely inhabit and operate a conventional computer.

---

### Era II: AIEN Owns Computation

Build:

```text
Binary Artifacts
Generations
Transformation IR
Physical Capability Graph
Physical Compiler
multiple execution backends
```

Outcome:

> Computation is defined by desired transformations instead of one ISA.

---

### Era III: AIEN Owns Its Physical Realization

Build:

```text
FPGA backend
Physical IR
reconfigurable circuits
multi-valued experiments
Wave IR
analog/continuous backends
```

Outcome:

> AIEN can choose or construct physical mechanisms for computation.

---

### Era IV: AIEN Connects Intent to Reality

Build:

```text
Intent Compiler
Desired State
physical effects
sensor feedback
closed-loop control
cross-domain orchestration
```

Outcome:

> AIEN can translate authorized human intent into measured physical change.

---

## 27. Delivery Order

The architectural vision must not distort engineering priority.

The dependency chain is:

```text
TRUST
 ↓
IDENTITY
 ↓
ARTIFACTS
 ↓
PERSISTENCE
 ↓
INTELLIGENCE
 ↓
TRANSFORMATION
 ↓
PHYSICAL COMPILATION
 ↓
EXOTIC PHYSICS
```

Therefore the practical order is:

```text
1. Finish M3 Trusted Machine
2. Freeze AIENOS ABI v1
3. Introduce Binary Artifact v0
4. Implement SEED-0B admission
5. Make storage + generations durable
6. Establish encryption + identity
7. Complete native networking
8. Complete useful native inference
9. Complete persistent Cortex + agent
10. Converge AEGIS / Worlds / J-Space
11. Mature Fabric
12. Introduce Transformation IR from real workloads
13. Add multiple Physical Compiler backends
14. Add a reconfigurable FPGA body
15. Introduce Physical IR
16. Research multi-valued logic
17. Research Wave IR / Hum of the Hive
18. Research analog and other physical substrates
19. Build generalized substrate bootstrap
20. Build Intent Compiler
21. Extend authorized transformations into physical environments
22. Demonstrate Intent → Verified Physical Reality
```

No hard dates are necessary.

Each gate is earned by evidence.

---

## 28. Repository Architecture

The project should not respond to every new concept by creating another repository.

Existing repositories should converge toward clear responsibilities.

### `aienos`

Owns the trusted body:

```text
boot
kernel
memory
tasks
scheduler
IPC
capabilities
devices
DMA
storage
networking substrate
hardware adapters
Physical Fabric enforcement
recovery
```

---

### `aien-sovereign-core`

Owns higher-level execution:

```text
runtime
model abstraction
World execution
J-Space orchestration
Transformation planning
compute orchestration
initial Physical Compiler work
```

As native AIENOS matures, Linux-specific machinery becomes a compatibility implementation rather than architectural truth.

---

### `aien-protocols`

Owns stable portable contracts:

```text
agent state
effects
events
evaluation
provenance
Binary Artifact
Transformation IR
Physical Capability Graph
Physical IR
Wave IR
bootstrap contracts
```

Only mature formats belong here.

Experimental structures should not be prematurely frozen as protocols.

---

### `aien-architecture`

Owns architectural law:

```text
system map
responsibility boundaries
ADRs
cross-repository contracts
roadmap
accepted invariants
future architecture
```

This master plan belongs conceptually here.

---

### `benchmarks`

Owns empirical truth:

```text
correctness
latency
throughput
memory
energy
temperature
precision
noise
stability
reconfiguration cost
physical resource use
```

Claims require receipts.

---

### `spark-rsi`

Owns improvement proposals and evaluation machinery.

It may propose better implementations.

It must not become the authority that promotes them.

---

### AEGIS

Long-term AEGIS should converge toward one canonical authority system rather than several overlapping policy implementations.

---

## 29. Canonical Objects

Over time the most important durable objects should become:

```text
Machine
Agent
Identity
Capability
Artifact
Generation
World
Intent
DesiredState
Transformation
PhysicalCapability
PhysicalRealization
EffectIntent
AdmissionReceipt
EvidenceReceipt
EpistemicRecord
```

These objects connect the full system.

A future AIEN should be understandable by inspecting their relationships rather than reading thousands of unrelated configuration files.

---

## 30. The Two Fundamental Loops

Nearly the entire architecture reduces to two loops.

### The Action Loop

```text
Intent
↓
Desired State
↓
Transformation
↓
J-Space
↓
AEGIS
↓
Effect
↓
Physical Reality
↓
Measurement
↓
Cortex
```

This loop changes reality.

### The Improvement Loop

```text
Evidence
↓
Cortex
↓
RSI
↓
Candidate
↓
World
↓
Evaluation
↓
J-Space
↓
AEGIS
↓
New Generation
```

This loop changes AIEN.

They must never collapse into one loop.

If the system that proposes an improvement can directly install it, the architecture has failed.

---

## 31. Hard Safety Invariants

These should remain true even in the deepest future architecture.

1. The model is never the root of trust.
2. Intelligence never implies authority.
3. Every external effect has an accountable principal.
4. Capabilities are explicit and revocable.
5. Speculation occurs in reversible state.
6. Reality changes only after authorization.
7. Generated code receives no ambient authority.
8. DMA is denied unless explicitly confined.
9. Physical configuration changes are effects.
10. RSI cannot authorize its own improvements.
11. Exact evaluated artifacts are the artifacts admitted.
12. Failed improvements roll back before repair.
13. Evidence distinguishes simulation, emulation and physical measurement.
14. A new hardware substrate does not automatically become trusted.
15. Recovery must not require the model.
16. Human operator authority remains available independently of agent reasoning.

---

## 32. Research Lanes That Must Not Block the Product

Keep these active, but separate from the critical path:

```text
direct GB10 acceleration
FPGA synthesis
multi-valued computation
Wave IR
Hum of the Hive
analog computing
optical computing
neuromorphic substrates
self-generated physical backends
```

Each can mature until it earns promotion into the main architecture.

This lets AIEN remain ambitious without turning the kernel roadmap into a physics research program.

---

## 33. First Major Product Boundary

The first complete AIEN product does not require Wave IR, FPGA synthesis or a Physical Compiler.

It requires:

```text
power on
↓
AIENOS
↓
local AIEN agent
↓
conversation / voice
↓
useful native model
↓
Cortex
↓
safe capabilities
↓
power off
↓
power on
↓
continues
```

That is the first system worth putting in someone's hands.

Everything deeper builds upon it.

---

## 34. Final Architectural Boundary

The final mature system looks like this:

```text
                       HUMAN
                         │
                         ▼
                    ┌─────────┐
                    │ INTENT  │
                    └────┬────┘
                         ▼
                ┌────────────────┐
                │ DESIRED STATE  │
                └───────┬────────┘
                        ▼
               ┌─────────────────┐
               │ TRANSFORMATION  │
               └───────┬─────────┘
                       │
             ┌─────────▼─────────┐
             │     J-SPACE       │
             │ possible futures  │
             └─────────┬─────────┘
                       ▼
                ┌────────────┐
                │   AEGIS    │
                │ authority  │
                └─────┬──────┘
                      ▼
             ┌───────────────────┐
             │ PHYSICAL COMPILER │
             └─────────┬─────────┘
                       ▼
              ┌──────────────────┐
              │ PHYSICAL FABRIC  │
              └─────────┬────────┘
                        ▼
      ┌─────────────────────────────────────┐
      │ CPU │ GPU │ FPGA │ WAVE │ ANALOG │ ? │
      └──────────────────┬──────────────────┘
                         ▼
                      PHYSICS
                         │
                         ▼
                      REALITY
                         │
                         ▼
                     SENSORS
                         │
                         ▼
                     EVIDENCE
                         │
                         ▼
                      CORTEX
                         │
                         ▼
                        RSI
```

---

## 35. What AIEN Eventually Becomes

AIEN begins as an operating system because an operating system is the first layer that must be owned.

It evolves into a persistent agent platform.

Then into a hardware-neutral transformation system.

Then into a physical compiler.

Eventually its deepest question is no longer:

> "Which instruction should the CPU execute?"

Nor even:

> "Which program should I run?"

It becomes:

> **"What permitted physical process can cause the requested state of reality to become true?"**

The system then finds a realization, verifies it, executes it, measures it and remembers what happened.

That is the fully zoomed-out architecture.

> **Intent → Meaning → Desired State → Transformation → Authority → Physical Realization → Physics → Reality → Evidence → Learning.**

Everything currently being built is a layer of that path.
