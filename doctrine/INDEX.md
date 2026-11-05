# DOCTRINE-INDEX-V1: SOVEREIGN MACHINE FOUNDATIONAL DOCTRINE CORPUS
## Milestone 0 (`DOCTRINE_V1`) Master Index, Cross-System Synthesis, and Gate Verification

```text
Milestone:         Milestone 0 (DOCTRINE_V1)
Corpus Identifier: AIEN-DOCTRINE-CORPUS-V1
Canonical Path:    doctrine/INDEX.md (repository-relative)
Classification:    Constitutional System Doctrine & Gate Ledger
Target Substrate:  AArch64 Host CPU + Blackwell/Hopper Accelerator Substrate
Status:            RATIFIED / CANONICAL / GATE VERIFIED
```

---

## 1. Executive Summary & Milestone 0 (`DOCTRINE_V1`) Definition

**Milestone 0 (`DOCTRINE_V1`)** constitutes the formal constitutional and ontological foundation of the **Sovereign Machine**.

The Sovereign Machine is not an operating system, an AI model, a compiler framework, or an application runtime. It is an autonomous, self-contained, self-verifying computational organism whose sole purpose is to permanently collapse the distance between human intention and physical reality:

$$\mathbf{\text{Human Intent}} \longrightarrow \mathbf{\text{Formal Semantics}} \longrightarrow \mathbf{\text{Authorized Transformation}} \longrightarrow \mathbf{\text{Physical Reality}} \longrightarrow \mathbf{\text{Verified Evidence}}$$

Before a single native instruction is admitted to bare-metal execution, before the physical memory management unit (MMU) is transitioned to sovereign control, and before cognitive models begin synthesizing realizations, the system’s mathematical, physical, cognitive, and epistemic boundaries must be cast in unyielding doctrine.

`DOCTRINE_V1` ratifies the seven foundational pillars of this architecture. Each document is exhaustive, authoritative, self-consistent, and grounded in physical and mathematical reality.

---

## 2. The Sovereign Architecture Stack

The seven doctrine files map directly to the functional and ontological layers of the Sovereign Machine:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        SOVEREIGNTY (DOCTRINE-SOV-001)                  │
│            Total Closure, No Foreign Runtimes, Severance Invariant      │
├────────────────────────────────────────────────────────────────────────┤
│                           AIEN (DOCTRINE-004)                          │
│            Sovereign Cognitive Engine, J-Space Planning, Active State  │
├──────────────────────────────────┬─────────────────────────────────────┤
│       OMEGA (AIEN-DOC-OMEGA-001) │         TRUST (DOCTRINE-005)        │
│    Semantic Calculus (G_S)       │   Epistemic Boundary & V-Ladder     │
│    Realization Graph (G_R)       │   (V0 ──► V5 Proof Carrying Code)   │
│    Machine Graph (G_M)           │   Failure Containment & Watchdogs   │
├──────────────────────────────────┴─────────────────────────────────────┤
│                          PHYSICS (DOCTRINE-002)                        │
│            Trusted Physical Authority, SMMUv3 DMA Isolation, AEGIS     │
├────────────────────────────────────────────────────────────────────────┤
│                           ATLAS (DOCTRINE-001)                         │
│            Irreducible Bootstrap Seed, Bare-Metal Initialization       │
├────────────────────────────────────────────────────────────────────────┤
│                       ARCHITECTURE (DOCTRINE-000)                      │
│            Master Blueprint, Four Permanent Layers, Substrate Map      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. The Seven Foundational Doctrine Documents

The `DOCTRINE_V1` corpus comprises seven canonical specifications located in [`doctrine/`](./):

```text
┌───┬───────────────────┬──────────────────┬───────────────────────────────────────────────────────────┐
│ # │ Document Path     │ Document ID      │ Canonical Title & Scope                                   │
├───┼───────────────────┼──────────────────┼───────────────────────────────────────────────────────────┤
│ 1 │ ARCHITECTURE.md   │ DOCTRINE-000     │ Sovereign Computational Architecture                      │
│ 2 │ ATLAS.md          │ DOCTRINE-001     │ Atlas — The Irreducible Bootstrap Seed                    │
│ 3 │ FORGE.md        │ DOCTRINE-002     │ Physics — The Trusted Machine Authority                   │
│ 4 │ OMEGA.md          │ DOCTRINE-OMEGA   │ The Omega Foundational Specification                      │
│ 5 │ AIEN.md           │ DOCTRINE-004     │ AIEN Foundational Doctrine: Sovereign Cognitive Engine    │
│ 6 │ TRUST.md          │ DOCTRINE-005     │ Trust — Epistemic Verification Doctrine & Trust Boundaries│
│ 7 │ DISCOVERY.md      │ DOCTRINE-006     │ Discovery & Physics Zero — Sovereign Scientific Intelligence│
│ 8 │ SOVEREIGNTY.md    │ DOCTRINE-SOV-001 │ Sovereignty and Closure: Canonical Law & Provenance       │
│ R │ ROADMAP.md        │ DOCTRINE-ROADMAP │ The 41-Milestone Sovereign Roadmap (M0-M40) & Status      │
└───┴───────────────────┴──────────────────┴───────────────────────────────────────────────────────────┘
```

---

### 3.1 [`ARCHITECTURE.md`](ARCHITECTURE.md) — DOCTRINE-000: Sovereign Computational Architecture
- **Document ID:** `DOCTRINE-000`
- **Scope:** Foundational Master System Specification; The Four Permanent Layers and The Sovereign Machine.
- **Core Principles:**
  - **Ontological Hierarchy:** Computation flows monotonically from Silicon $\to$ Atlas $\to$ Physics $\to$ Omega $\to$ Aien.
  - **The Four Permanent Layers:** Substrate Layer, Authority Layer, Meaning Layer, Cognitive Layer.
  - **The Permanent Architectural Rule:** No transient implementation choice (Rust, AArch64, CUDA, Linux, PyTorch) may become the permanent definition of the machine.
  - **Single Composition Root:** Deterministic wiring across all layers with zero dynamic service locators or circular dependencies.
- **Key Invariants:**
  - Unidirectional dependency flow: higher layers depend on lower layers; lower layers possess zero awareness of higher layers.
  - The machine functions continuously and deterministically even if all cognitive models are unloaded.

---

### 3.2 [`ATLAS.md`](ATLAS.md) — DOCTRINE-001: Atlas — The Irreducible Bootstrap Seed
- **Document ID:** `DOCTRINE-001`
- **Scope:** Bare-metal reset, hardware measurement, identity mapping, and monotonic handoff to Physics.
- **Core Principles:**
  - **Five Tenets of Atlas:** Small, Fixed, Auditable, Deterministic, Non-Intelligent.
  - **The Executable Identity Invariant:**
    $$\text{tested bytes} \equiv \text{evaluated bytes} \equiv \text{authorized bytes} \equiv \text{executed bytes}$$
  - **The Canonical Supporting Evidence Bundle:** Seven immutable artifacts (`atlas.bin`, `atlas.manifest`, `atlas.sha256`, `atlas.decode`, `atlas.memory-map`, `atlas.control-flow`, `atlas.audit`).
- **Key Invariants:**
  - Zero cognitive mechanisms, zero neural weights, zero heap allocation, zero dynamic syscalls.
  - Monotonic handoff at the exception level declared by the machine contract (no implicit EL2 -> EL1 transition): once control is transferred to Physics, Atlas is never re-entered within the boot epoch.

---

### 3.3 [`FORGE.md`](FORGE.md) — DOCTRINE-002: Physics — The Trusted Machine Authority
- **Document ID:** `DOCTRINE-002`
- **Scope:** Physical execution governance, MMU/SMMUv3 management, hardware capability enforcement, and effect admission.
- **Core Principles:**
  - **The Physical Mandate:** "What is allowed to become physically real?" Physics is the Constitution of the Machine.
  - **AEGIS Invariant & Capability Verification:** Unforgeable, cryptographically validated capability contracts checking every MMIO dereference, DMA transaction, and PCIe doorbell toggle.
  - **Hardware SMMUv3 DMA Sandboxing:** Stage-2 page table confinement isolating all accelerator memory access from host kernel RAM.
- **Key Invariants:**
  - Intelligence proposes; Physics disposes. No effect acts upon reality without an authorized `EFFECT_INTENT` token.
  - Hardware watchdogs ($T_{hard} = 1000\text{ ms}$) assert non-maskable capability revocation and Function-Level Reset (FLR) on accelerator hang.

---

### 3.4 [`OMEGA.md`](OMEGA.md) — DOCTRINE-OMEGA-001: The Omega Foundational Specification
- **Document ID:** `AIEN-DOC-OMEGA-001`
- **Scope:** The Semantic Language, Realization Substrate, and Tri-Graph Model for the Sovereign Machine.
- **Core Principles:**
  - **The Decoupling Principle:** Meaning must never be permanently coupled to representation, nor semantics to physical execution.
  - **The Tri-Graph Model:**
    1. **Semantic Graph ($G_S$):** Pure declarative representation of mathematical intent, invariants, shapes, and constraints.
    2. **Realization Graph ($G_R$):** Concrete physical manifestations, direct machine code, schedules, and verified execution proofs.
    3. **Machine Graph ($G_M$):** Hardware topology, vector widths, tensor cores, cache line structures, and thermal limits.
  - **Continuous Adaptive Compilation:** Dynamic matching of semantic intent to available silicon without static intermediate compiler bloat.
- **Key Invariants:**
  - $G_S$ is immutable and substrate-agnostic.
  - Realizations are transient, disposable, and continually refined via empirical profiling.

---

### 3.5 [`AIEN.md`](AIEN.md) — DOCTRINE-004: AIEN Foundational Doctrine
- **Document ID:** `DOCTRINE-004`
- **Scope:** Sovereign Cognitive Core, J-Space Planning, Active State, and Semantic Memory.
- **Core Principles:**
  - **The Cognitive Mandate:** Autonomous synthesis of desired states, hypothetical transformation plans, and candidate realizations.
  - **J-Space Speculative Planning:** Branchable, counterfactual execution worlds that evaluate futures without modifying external reality.
  - **Dual-Loop Cognitive Engine:** Rapid inner-loop reactive dispatch paired with deep outer-loop reflective synthesis and memory promotion.
- **Key Invariants:**
  - Aien is an unprivileged producer of hypotheses.
  - Every proposed mutation must be verified by AEGIS against capability contracts before lowering and execution.

---

### 3.6 [`TRUST.md`](TRUST.md) — DOCTRINE-005: Trust — Epistemic Verification Doctrine
- **Document ID:** `DOCTRINE-005`
- **Scope:** Epistemic verification boundaries, the Verification Ladder ($V_0 \to V_5$), correctness vs. performance authority, and failure containment.
- **Core Principles:**
  - **The Epistemic Axiom:** $\mathbf{\text{Intelligence} \ne \text{Authority}}$. Search, optimization, neural models, and e-graphs are strictly UNTRUSTED. Omega contracts, verification kernels, and Physics admission are TRUSTED.
  - **The Six-Tier Verification Ladder:**
    - $V_0$: Structural & Capability Verification (syntax, shapes, buffer ranges $[base, base+size)$).
    - $V_1$: Differential Verification (parity against golden EL1/EL0 scalar reference within $\epsilon_{tol}$).
    - $V_2$: Property-Based Invariant Verification (conservation laws, algebraic invariants, monotonicity).
    - $V_3$: Adversarial Corner Fuzzing (denormals, NaNs, zero-strides, cache line bank conflicts).
    - $V_4$: Symbolic Equivalence Verification (polyhedral dependence proofs, e-graph rewrite certificates).
    - $V_5$: Proof-Carrying Realization (PCR: untrusted agent provides formal proof $\Pi$; trusted kernel checks $\Pi$ in $O(|\Pi|)$ polynomial time).
  - **Authority Separation:** Verification answers "Is this allowed?" (absolute veto); Profiling answers "Should this realization run?" (empirical Pareto guidance).
- **Key Invariants:**
  - Fast garbage remains garbage: performance metrics can never override a verification failure.
  - Fault containment guarantees soundness even under total cognitive compromise or accelerator lockup.

---

### 3.7 [`SOVEREIGNTY.md`](SOVEREIGNTY.md) — DOCTRINE-SOV-001: Sovereignty and Closure
- **Document ID:** `DOCTRINE-SOV-001`
- **Scope:** The Sovereignty Law, The Severance Invariant, Self-Hosting Closure, and The Oracle Principle.
- **Core Principles:**
  - **The Sovereignty Law:** The final deployed Sovereign Machine must not depend upon Rust, Cargo, LLVM, GCC, Python, Linux, POSIX, CUDA, PyTorch, or foreign weights.
  - **The Severance Invariant:** If all external repositories, cloud providers, and foreign toolchains vanish, the machine continues self-executing and evolving indefinitely.
  - **The Founding Exception & The Scaffold:** Temporary reliance on modern toolchains during initial bootstrapping, subject to strict deprecation horizons terminating at sovereign closure (closure gate placement on the M0-M40 roadmap pending the SOVEREIGNTY.md rewrite, aien-spark/aien-architecture#8).
  - **The Oracle Principle:** Epistemic grounding using external instruments as temporary measurement comparators, never as operational dependencies.
- **Key Invariants:**
  - Absolute self-hosting: every compiler, kernel, scheduler, and weight is built from self-contained lineage.
  - Cryptographic provenance: 100% of all code and model training artifacts are immutably signed.

---

## 4. Cross-Cutting Doctrinal Synthesis

The power of `DOCTRINE_V1` lies in the airtight mathematical and operational coherence across all seven specifications:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   CROSS-CUTTING DOCTRINAL INVARIANTS                   │
├──────────────────────────┬─────────────────────────────────────────────┤
│ Invariant                │ Doctrinal Interaction                       │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 1. Intelligence !=       │ AIEN.md proposes; TRUST.md verifies;        │
│    Authority             │ FORGE.md authorizes; ATLAS.md boots.      │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 2. Decoupling of Meaning │ OMEGA.md specifies invariant semantics;     │
│    from Representation   │ TRUST.md proves equivalence;                │
│                          │ ARCHITECTURE.md prevents premature lowering.│
├──────────────────────────┼─────────────────────────────────────────────┤
│ 3. Executable Identity   │ ATLAS.md establishes tested == executed;    │
│                          │ TRUST.md records Merkle digests;            │
│                          │ SOVEREIGNTY.md seals self-hosting closure.  │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 4. Separation of Proofs  │ TRUST.md & FORGE.md enforce:              │
│                          │ Integrity (unkeyed) != Auth (signed) !=     │
│                          │ Freshness (monotonic hardware counters).    │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 5. Physical Confinement  │ FORGE.md (SMMUv3) + AEGIS verifier        │
│    under Malice          │ strictly isolate untrusted AIEN execution.  │
└──────────────────────────┴─────────────────────────────────────────────┘
```

---

## 5. Milestone 0 (`DOCTRINE_V1`) Gate Verification & Sign-Off

The `DOCTRINE_V1` Gate requires satisfying seven strict verification criteria before Milestone 1 (`ATLAS_BOOT`) may be entered:

### 5.1 Gate Verification Criteria Matrix

| Gate Criterion | Verification Standard | Audited Evidence | Status |
| :--- | :--- | :--- | :---: |
| **G0-1: Corpus Completeness** | All seven foundational doctrine documents authored, formatted, and cross-referenced in `doctrine/`. | Verified on physical filesystem. | `PASSED` |
| **G0-2: Ontological Consistency** | Zero terminological or authority contradictions across documents. Unidirectional dependency hierarchy verified. | Cross-audit of layers and definitions. | `PASSED` |
| **G0-3: Epistemic Boundary** | Search, optimization, and neural inference strictly designated untrusted; verification and physics designated trusted. | Enforced in `TRUST.md` and `FORGE.md`. | `PASSED` |
| **G0-4: Mathematical Rigor** | Formal definitions provided for Omega Tri-Graphs, Verification Ladder ($V_0 \to V_5$), and Epistemic Merkle DAGs. | Evaluated in `OMEGA.md` and `TRUST.md`. | `PASSED` |
| **G0-5: Hardware Realism** | Concrete alignment with AArch64 bare-metal (EL1/EL0, SMMUv3) and heterogeneous accelerator reset rails. | Fully specified in `FORGE.md` & `ATLAS.md`.| `PASSED` |
| **G0-6: Sovereignty Invariants** | Absolute prohibition of foreign runtimes in operational target; strict deprecation horizons for bootstrap scaffolds. | Formally codified in `SOVEREIGNTY.md`. | `PASSED` |
| **G0-7: Provenance Anchoring** | Separation of Proofs established; unkeyed integrity, keyed auth, and anti-rollback freshness specified. | Codified in `TRUST.md` & `SOVEREIGNTY.md`.| `PASSED` |

### 5.2 Formal Ratification & Gate Sign-Off

```text
================================================================================
                    MILESTONE 0 (DOCTRINE_V1) GATE RATIFICATION
================================================================================
Milestone Identifier:    Milestone 0: DOCTRINE_V1
Verification Authority:  Sovereign Machine Architecture & Governance Board
Ratification Date:       2026-09-25T23:04:00Z
Target Substrate:        AArch64 Host CPU + Blackwell/Hopper Accelerator Fabric

Verified Corpus Elements:
  [✓] DOCTRINE-000: ARCHITECTURE.md  (Sovereign Computational Architecture)
  [✓] DOCTRINE-001: ATLAS.md         (The Irreducible Bootstrap Seed)
  [✓] DOCTRINE-002: FORGE.md       (The Trusted Machine Authority)
  [✓] DOCTRINE-OMEGA: OMEGA.md       (The Omega Foundational Specification)
  [✓] DOCTRINE-004: AIEN.md          (The Sovereign Cognitive Engine)
  [✓] DOCTRINE-005: TRUST.md         (Epistemic Verification & Trust Boundaries)
  [✓] DOCTRINE-006: DISCOVERY.md     (Discovery & Physics Zero)
  [✓] DOCTRINE-SOV: SOVEREIGNTY.md   (Sovereignty, Closure & Provenance)
  [✓] DOCTRINE-IDX: INDEX.md         (Master Index & Gate Verification Ledger)

GATE STATUS:             RATIFIED / CLOSED (current milestone status: see ROADMAP.md)
Sign-off Hash:           4a8b79e13d964fcf81ec0a1f9e2b1735cb0e4871d87a2cf956102a9e25d2b77c
================================================================================
```


---

## 4. The Sovereign Program-Learning Doctrine (Omega Synthesis → AIEN)

### 4.1 The Synthesis Doctrine
> **`ALLEN INTENDS.`**  
> **`AIEN PROPOSES.`**  
> **`OMEGA DEFINES.`**  
> **`FORGE REALIZES.`**  
> **`AEGIS VERIFIES.`**  
> **`HARDWARE ACTS.`**  
> **`EVIDENCE TEACHES.`**

### 4.2 The Three Speeds of Intelligence
1. **Fast Learning (AIEN Model / Search Prior):** *"What should I try next?"* Implicit, speculative intuition. Search prior over Omega's possibility space. Rapidly retrainable and disposable.
2. **Medium-Term Learning (Omega Procedure Library):** *"What reusable procedures have we discovered?"* Explicit, typed, composable, verifiable semantic subgraphs.
3. **Long-Term Knowledge (Omega Semantics + Proofs + Cortex Evidence):** *"What does this mean? What has been verified? What was observed?"* Durable epistemic ground.

### 4.3 Division of State & Durability
* **Weights** hold search intuition.
* **Programs** hold explicit procedure.
* **Omega Abstractions** hold reusable concepts.
* **Cortex** holds empirical experience.
* **Proofs** hold trusted justification.
* **Physics** holds physical machine authority.

### 4.4 Trust Decomposition Inside OMEGA
The epistemic boundary runs directly through OMEGA. Search and synthesis components are strictly UNTRUSTED; semantic contracts and verification checkers are TRUSTED:

```text
OMEGA
├── OMEGA SEMANTIC CORE          TRUSTED CONTRACT
├── OMEGA VERIFIER               TRUSTED CHECKER
├── OMEGA SYNTHESIS              UNTRUSTED SEARCH
├── OMEGA ABSTRACTION MINER      UNTRUSTED SEARCH
├── OMEGA REALIZATION SEARCH     UNTRUSTED SEARCH
└── OMEGA LIBRARY
      ├── CANDIDATE               UNTRUSTED
      └── VERIFIED/PROMOTED       TRUSTED BY EVIDENCE
```

Canonical Synthesis Pipeline:
```text
AIEN
  ↓
CANDIDATE IDEA

OMEGA SYNTHESIS / COMPOSITION
  ↓
CANDIDATE PROGRAM OR REALIZATION

OMEGA TRUSTED VERIFIER
  ↓
VERIFIED SEMANTIC CANDIDATE

PHYSICS
  ↓
AUTHORIZED PHYSICAL EFFECT
```

### 4.5 Sovereign Training Corpus Scoping
> *Omega's sovereign search traces provide the cold-start training corpus for AIEN-0, removing the need for a foreign pretrained search-guide model or foreign procedural training corpus.*


> **Naming note:** current machine realization is FORGE under ADR 0014. Historical PHYSICS identifiers in milestone/evidence records remain valid provenance.
