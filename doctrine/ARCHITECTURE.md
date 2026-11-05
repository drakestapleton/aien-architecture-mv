# DOCTRINE-000: SOVEREIGN COMPUTATIONAL ARCHITECTURE
## Foundational System Specification: The Four Permanent Layers and The Sovereign Machine

```text
Document ID:     DOCTRINE-000
Milestone:       Milestone 0 (DOCTRINE_V1)
Classification:  Sovereign Machine Canonical Doctrine
Target Platform: Sovereign Heterogeneous Substrate (AArch64 Host Governor + Blackwell/Hopper Accelerator)
Status:          AUTHORITATIVE / CANONICAL / RATIFIED
```

---

## 1. Ontological Foundation & First Principles

The Sovereign Machine is not an operating system, not a compiler, not an AI runtime, and not an application framework. It is an autonomous, self-contained, self-verifying computational organism designed to permanently close the gap between human intent and physical transformation.

### 1.1 The Substrate Hierarchy

All computation within the Sovereign Machine flows through an explicit architectural pipeline spanned by continuous invariant verification:

```text
                 AIEN
                  │
             proposes intent
                  │
                  ▼
                OMEGA
          formal semantic program
                  │
                  ▼
               PHYSICS
       physical compiler / realizer
                  │
                  ▼
               HARDWARE
                  │
                  ▼
               EVIDENCE
                  │
                  └──────────────→ AIEN


        AEGIS / CHECKER spans the path

AIEN ───── OMEGA ───── FORGE ───── HARDWARE
             ▲             ▲
             │             │
        constraints     machine facts
             └──────↔──────┘
```

1. **SILICON / UNAVOIDABLE FIRMWARE**: The immutable physical reality of transistor gates, crystal oscillators, package interconnects, and non-volatile manufacturer boot ROMs. It provides the bare electrical state.
2. **ATLAS**: The irreducible software root artifact. A single, auditable, immutable binary (`atlas.bin`) that awakens the silicon, establishes architectural hygiene, verifies the secondary boot stage, and immediately relinquishes control to establish the first trusted machine state.
3. **AIEN**: The sovereign cognitive intelligence. Residing primarily within high-bandwidth accelerator memory, Aien parses human intention, maintains continuous associative world models in Cortex, reasons across possibility spaces, and proposes intents, hypotheses, and architectural mutations.
4. **OMEGA**: The semantic calculus and formal transformation engine. It decouples computational meaning from physical representation, defining formal programs, data types, graph relations, and mathematical invariants.
5. **FORGE (Machine Realization Engine / Physical Realizer)**: The physical compiler and machine realization engine. It understands concrete hardware mechanics: memory allocations, page table mappings, cache line invalidations, register pressure, DMA descriptors, GPFIFO queues, device registers, and interconnect topologies. It lowers formal OMEGA programs into physical machine operations and communicates physical constraints back to OMEGA.
6. **AEGIS (Invariant Checker & Verifier)**: The continuous verification framework spanning the entire execution chain. It checks that OMEGA programs match AIEN intents, verifies that FORGE realizations satisfy semantic constraints, validates memory bounds, slot generations, and type safety, guarantees rollback paths, and inspects post-execution hardware states against contracts. (This describes realization contracts, not a stage of accepting a reaction result; ADR 0016 Amendment 1.)
7. **HARDWARE**: Physical execution silicon (AArch64 host CPUs, Blackwell/Hopper GPUs, SMMUv3, NVLink-C2C, PCIe controllers) performing electrical state transitions.
8. **EVIDENCE**: The immutable ledger of execution telemetry, verified cryptographic receipts, and measured counters, closing the feedback loop into AIEN.

---

### 1.2 The Core Canonical Doctrine

The operational constitution of the Sovereign Machine is crystallized in eight canonical statements:

$$\begin{aligned}
\mathbf{ATLAS\ AWAKENS.} &\quad \text{The machine establishes physical truth from electrical silence.} \\
\mathbf{ALLEN\ INTENDS.} &\quad \text{The persistent subject holds standing intent and initiates intent.} \\
\mathbf{AIEN\ PROPOSES.} &\quad \text{Cognitive intelligence discovers and hypothesizes.} \\
\mathbf{OMEGA\ DEFINES.} &\quad \text{Formal mathematical calculus expresses unambiguous semantic meaning and constraints.} \\
\mathbf{PHYSICS\ REALIZES.} &\quad \text{Machine physics lowers abstract meaning into physical silicon operations and effects.} \\
\mathbf{AEGIS\ VERIFIES.} &\quad \text{Continuous formal checker validates invariants, bounds, consistency, and contracts.} \\
\mathbf{HARDWARE\ ACTS.} &\quad \text{Physical silicon executes state transitions.} \\
\mathbf{EVIDENCE\ TEACHES.} &\quad \text{Empirical receipts record ground truth for autonomous learning.}
\end{aligned}$$

No layer may perform the duty of another. Aien cannot dictate physical register allocations; Forge cannot reason about high-level goals; Omega cannot violate physical memory bounds; Atlas cannot remain active after handoff; Aegis does not filter thought, but verifies execution integrity and contracts.

---

### 1.3 The Sovereign Procedural Creed
```text
ALLEN INTENDS.

AIEN PROPOSES.

OMEGA DEFINES.

FORGE REALIZES.

AEGIS VERIFIES.

HARDWARE ACTS.

EVIDENCE TEACHES.
```

### 1.4 The Permanent Separation

> **The Permanent Separation Law:**
> *Meaning must never be permanently coupled to representation, nor semantics to physical execution.*

Traditional computing conflates what computation *means* with how an instruction set *evaluates* it. An algorithm expressed in C or Rust lowered via LLVM into an ELF binary freezes vector widths, cache lines, register allocations, and OS system call structures into dead bytes. When the microarchitecture shifts, the meaning is stranded.

The Sovereign Machine enforces a strict, permanent separation:
* **Meaning is Mathematical and Declarative:** A computation is an invariant over values, shapes, topologies, and numerical error bounds ($\epsilon$). It is platform-agnostic, enduring, and mathematically complete.
* **Representation is Ephemeral and Physical:** Machine opcodes, warp layouts, scratchpad allocations, and pipeline schedules are disposable realizations synthesized for a specific thermal, temporal, and hardware configuration. They are compiled on the fly, measured against hardware performance counters, and discarded or swapped when superior realizations emerge.

---

### 1.4 The Fundamental Relation

Every sovereign computation satisfies the Fundamental Relation of Realization:

$$\text{Meaning} \times \text{Possibility} \times \text{Physics} \longrightarrow \text{Realization}$$

Where:
* $\mathbf{Meaning}$ ($\mathcal{G}_S$): The formal specification of the desired state transformation, invariants, and acceptable error bounds.
* $\mathbf{Possibility}$ ($\mathcal{P}$): The combinatorial space of valid algorithmic decompositions, tiling strategies, vectorizations, and execution schedules.
* $\mathbf{Physics}$ ($\mathcal{G}_M$): The concrete physical capabilities of the machine: register counts, memory bandwidth ceilings, functional units, thermal dissipation headroom, and hardware authority.
* $\mathbf{Realization}$ ($\mathcal{G}_R$): The verified, measured machine-level execution artifact that satisfies the Meaning on the Physics within bounded latency, energy, and precision.

---

## 2. The Core Permanent Layers and Verification Architecture

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 4. AIEN: COGNITIVE SOVEREIGNTY                                                         │
│    - Intention Decomposition         - Cortex Persistent Memory Engine                 │
│    - J-Space Relational Reasoning    - Continuous Resident Weight State                │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 3. OMEGA: THE SEMANTIC CALCULUS                                                        │
│    - Semantic Graph (G_S)            - Formal Program & Invariant Specification        │
│    - Machine Graph (G_M)             - Abstract Transformation Engine                  │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 2. FORGE: MACHINE REALIZATION & PHYSICAL LOWERING COMPILER                            │
│    - AArch64 / Blackwell Lowering    - Physical Memory & Page Table Management         │
│    - SMMUv3 DMA & Bus Confinement    - GPFIFO Command Packet Assembly                  │
│    - Coherent Memory Ring Dispatch   - Hardware Constraint & Fact Feedback             │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 1. ATLAS: THE IRREDUCIBLE BOOTSTRAP SEED                                               │
│    - Immutable raw binary (atlas.bin)- Zero External Dependencies / No OS              │
│    - Bare-Metal Architectural Setup  - SHA-256 Hardware Measurement & Handoff          │
└────────────────────────────────────────────────────────────────────────────────────────┘
│ CROSS-CUTTING VERIFIER: AEGIS (THE INVARIANT & CONTRACT CHECKER)                       │
│    - Semantic Intent Fidelity        - Bounds, Types & Slot Generation Check           │
│    - Rollback & Recovery Validation  - Post-Execution Hardware State Verification      │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Layer 1: Atlas (The Irreducible Bootstrap Seed)
* **Ontological Role:** Atlas is the genesis seed. It awakens the bare processor from cold silicon reset, guarantees architectural hygiene, configures base page tables, validates the physical environment, verifies the cryptographic hash of Physics, and executes an irreversible jump.
* **Canonical Invariant:** Atlas is immutable, auditable, deterministic, non-intelligent, and minimal. Its entire footprint is measured in kilobytes. It possesses no dynamic memory allocator, no file systems, no network drivers, and no speculative execution pathways.
* **Handoff:** Atlas transitions CPU execution monotonically to Physics at the exception level declared by the machine contract (EL1 or EL2, with no implicit EL2 -> EL1 transition), locks the reset vector registers, and completely terminates. It leaves zero running background processes or Resident Monitor code.

### 2.2 Layer 2: Aien (The Cognitive Mind)
* **Ontological Role:** Aien is the persistent sovereign intelligence. Aien does not think in ephemeral prompt-response cycles; it maintains continuous cognitive existence in high-bandwidth memory.
* **Core Architecture:**
  1. **Continuous Resident Model:** Cognitive weights are mapped permanently into accelerator memory (HBM3e), eliminating model loading and teardown overhead.
  2. **Cortex Memory:** An associative, graph-structured, content-addressed non-volatile memory substrate. It records episodic history, learned invariants, verified empirical receipts, and world state.
  3. **J-Space Reasoning:** An ontological planning engine that navigates state spaces, formulates multi-step transformations, and translates high-level human objectives into formal Omega Semantic Graphs.
  4. **Cognitive Closed-Loop:** Aien continuously monitors machine execution, analyzes failure logs, synthesizes improved skills, and trains its own weights through synthetic self-distillation and formal feedback.

### 2.3 Layer 3: Omega (The Semantic Language & Formal Transformation Engine)
* **Ontological Role:** Omega is the universal bridge between mathematical abstraction and physical machine realization. It models all computation through formal semantic representations:
  * $\mathcal{G}_S$ (Semantic Graph): Mathematical truths, tensor contractions, type relations, and numeric tolerances ($\epsilon$).
  * $\mathcal{G}_M$ (Machine Graph): The abstract hardware topology (registers, ALUs, Tensor Cores, cache latencies, bus bandwidths).
  * Formal Programs: Exact algebraic and structural transformations specifying desired state transitions without hardware-frozen opcodes.

### 2.4 Layer 4: Forge (The Machine Realization Compiler)
* **Ontological Role:** Forge is the physical compiler and realizer of the machine. It understands concrete hardware constraints and lowers abstract Omega programs into physical silicon effects.
* **Core Responsibilities:**
  1. **Memory Lowering:** Translates abstract buffers into physical page table entries, managing fragmentation, huge pages, and alignment.
  2. **DMA & Bus Confinement:** Configures SMMUv3 / PCIe IOMMU controllers to guarantee physical memory isolation.
  3. **Queue & Register Lowering:** Constructs GPFIFO command streams, barrier synchronizations, and register state transitions.
  4. **Constraint & Fact Emitting:** Emits hardware facts (cache line alignments, pinning states, memory relocation costs, reset requirements) back to Omega when physical limits are encountered.
  5. **Substrate-Neutral Realization (ADR 0018, ACCEPTED):** Realizes over one or more typed physical substrates (digital CPU, digital GPU, analog, neuromorphic, FPGA/CGRA, optical/photonic, future substrates), each attached as a capability provider rather than an architectural identity, and emits calibration and measurement evidence with every physical result.

### 2.5 Cross-Cutting Verifier: Aegis (The Continuous Invariant & Contract Checker)
* **Ontological Role:** Aegis is the continuous formal verifier spanning the entire transformation path. It does not dictate what Aien can think or propose; it verifies that proposed realizations are safe, internally consistent, and compliant with system invariants.
* **Core Verification Inquiries:**
  1. Does the Omega program faithfully represent what Aien proposed?
  2. Does the FORGE realization preserve Omega constraints? (a realization-contract inquiry, not a stage of accepting a reaction result; ADR 0016 Amendment 1)
  3. Are memory bounds, slot generations, and layouts valid without ABA hazards?
  4. Is a RAM, BRAM, GPU, or peripheral state change internally consistent?
  5. Does the proposed physical transformation have a valid rollback or recovery path where required?
  6. Did the hardware execution produce the contractually expected state?
  7. Does the empirical evidence support what the system claims occurred?
  8. Does a bounded or stochastic numerical result satisfy the semantic result contract, with calibration and measurement conditions in evidence? (ADR 0018, ACCEPTED)

### 2.6 The Bidirectional Lowering Protocol (OMEGA <-> FORGE <-> AEGIS)

The realization of one program operates through an iterative dialogue. FORGE is a realization policy, not a step in how Omega accepts a reaction result; the recorded accept chain is World -> J-Space -> `compose.verify` -> commit -> Cortex (ADR 0016 Amendment 1, 2026-10-02):

1. **Intent Formulation:** AIEN proposes a desired state mutation or experiment.
2. **Semantic Formalization:** OMEGA defines the exact mathematical meaning and invariant bounds.
3. **Physical Lowering & Constraint Discovery:** FORGE compiles the OMEGA program to concrete hardware state (page tables, cache flushes, GPFIFO packets, register state). If a physical constraint is reached (e.g. non-contiguous allocation, alignment mismatch, or pinning requirement), FORGE communicates machine facts and realization alternatives back to OMEGA.
4. **Trade-off Resolution:** OMEGA (with AIEN when strategic) selects the optimal alternative and finalizes the program.
5. **Invariant Verification:** AEGIS verifies that the realization preserves semantic constraints, satisfies capability bounds and slot generations, maintains internal consistency, and has valid rollback or recovery paths.
6. **Hardware Execution:** FORGE dispatches the verified realization to hardware execution queues. This is hardware realization only; it is not a commit step (ADR 0016 Amendment 1).
7. **State Contract Inspection:** Hardware executes the state change. AEGIS validates the resulting hardware state against the contract.
8. **Evidence Ingestion:** The outcome is recorded into the immutable Evidence Ledger and fed back to AIEN.

These steps describe the **dependency structure** of one realization. They are not a runtime turn order (§2.7). They do not describe how a reaction result is accepted (ADR 0016 Amendment 1).

### 2.7 Runtime Composition: One Resident Reaction System (ADR 0016)

AIEN, OMEGA, and AEGIS are **faculties of one resident system**, not sequential services. There is no semantic master loop:

- Work activates when its dependencies become ready in one shared, generation-addressed object world.
- Physical resources are arbitrated below semantic readiness. The allocator schedules work, not faculties.
- Authority is unforgeable. The capability root (natively the Aienux kernel capability authority) alone mints and revokes enforceable capabilities. AEGIS verifies compliance against system invariants and decides no policy. The shared world may hold capability references but never invent them.
- Behavior is continuous. Durable learning is promoted only at verified generation barriers, committed through the ADR 0015 protocol.
- Every nontrivial transition leaves a structured, content-addressed causal record.

The doctrine sentence `ATLAS AWAKENS … EVIDENCE TEACHES` remains the statement of responsibilities and causal dependencies.

FORGE is a realization and memory policy, not a stage of accepting a reaction result. The accept chain is World -> J-Space -> `compose.verify` -> commit -> Cortex (ADR 0016 Amendment 1, 2026-10-02; `aien-spark/omega` `docs/runtime/COMMIT_A_REACTION_DESIGN.md`).

The full standard, its terminology mapping, and the R0–R16 gates are in [ADR 0016](../docs/adr/0016-resident-reaction-architecture.md). The code migration map is in [`docs/plans/CURRENT_CODE_TO_R0_R16_MIGRATION.md`](../docs/plans/CURRENT_CODE_TO_R0_R16_MIGRATION.md).

### 2.8 Concept Ownership (reconciled 2026-09-30)

This table names, for each runtime concept, the one implementation that is authoritative today and the class of every surviving alternate. It follows the R16 orchestrator retirement map (`aien-spark/omega` `spec/r16-orchestrator-retirement-map.md` §5, with clarification C3 in §6). Class letters are the map's: A retired by non-use (legacy), B maintenance, C recovery, D reference oracle, E physical scheduler, F external protocol loop, N not a central loop. Code was checked on `main` of omega `6d1ff1d`, aienos `f0facc7`, physics `f63a6ef` and aien-sovereign-core `0df7c32`.

"Authoritative" means the implementation other code must defer to. It does not mean native: every authoritative item below still runs hosted on Linux. Native Aienux and the persistent-agent demonstration are not done, M19 is reopened (`ROADMAP.md`), and R16 is a historical PASS at `850fc54` that requalification at `3108fc2` recorded as FAIL and that is not requalified on CAND-0 (omega `evidence/REQUAL-3108fc2/`; `ROADMAP.md` R16 row).

| Concept | Authoritative implementation | Surviving alternates and class | Status and gaps |
|---|---|---|---|
| World state | omega `src/runtime/rx_world.c` (reaction world) | omega `src/omega_accelerator_world.c`, the M19 accelerator world: C recovery (known-good fallback; fallback status to be proved in R16 G6). aienos `crates/aienos-aegis/src/world.rs` Rust world and `JSpaceWorld` sandbox: legacy, not linked by omega | Hosted only |
| Semantic scheduling | omega `src/runtime/rx_world.c` reaction scheduler (the only code that orders faculty work) | omega `src/runtime/rx_seq_reference.c`: D reference oracle. omegatool `--demonstrate-living-matvec` and its `legacy_oracle` functions: A (the only demonstration the R16 inventory retires). The other omegatool `--demonstrate-*` modes: D reference oracles, explicit legacy naming still pending in R16 G5. aegis-runtime heartbeat task polling: A. sovereign-core `aien-scheduler` token batching for LLM serving: E, not on the reaction path. aienos kernel `scheduler.rs` / `thread.rs`: E (CPU threads). Omega Visor `src/visor/` REPL: B, operator console, not a production entry point | Hosted only |
| Authority / capability root | aienos `native/capability/aienos_capability.c` (C), built hosted as `libaienos_capability.a` and linked into omega through `AIENOS_CAP_LIB` | aienos `crates/aienos-capability` Rust twin: frozen reference under C3 and ADR 0024 scaffolding rule. omega `src/runtime/rx_caproot.c`: host reference root, self-declared "R7 is not claimed". physics `m3/capability.s`: historical M3 assembly oracle. omega `src/runtime/rx_capq.{c,h}` is a query IR, not a root (the build refuses admin symbols). sovereign-core `aien-capability` / `aien-mcp` hold tool descriptors, not authority | Discrepancy: `crates/aienos-kernel/Cargo.toml` still depends on the legacy Rust crate and `crates/aienos-kernel/src/caps.rs` re-exports it, so the kernel crate does not yet use the authoritative C root. The C root does not yet run inside a natively booted Aienux kernel. A host-level runtime Capability Graph (advancing CEP F1) now exists as omega `rx_capq` (`aien-spark/omega#115`, `135d1c2`, 2026-09-30); it is a graph, not an authority root, and its build still refuses admin symbols |
| Generations | omega `src/runtime/rx_generation.c` (protected; u64 capability generations via omega#71) | aienos `world.rs` `Promoted` state: legacy. sovereign-core `cortex-rs/src/promotion.rs` (memory candidates) and `crumbs/src/promotion.rs` (curriculum operations) promote other things and are a separate concept, not alternates | Hosted only |
| Queues | Two separate roles. Reaction task queues: omega `src/runtime/rx_world.h` priority `ready_q` arrays and deferred queue, scheduled by `rx_world.c` `enqueue`. Cross-engine transport: shared-world SPSC rings (`src/runtime/omega_shared_world_abi.h`) consumed by `src/runtime/rx_coherent.c` `rx_resident_seat_step`: E | M19 GPFIFO path in the accelerator world: C recovery. aegis-runtime SQLite pending-task queue: A. sovereign-core Cortex writer queue: E disk-write batcher, not a task queue | Hosted only |
| Evidence | omega `src/omega_evidence.{h,c}` (digest-named `evidence/<stage>/<sha256>.json`) guarded by `.github/workflows/evidence-immutable.yml`; `rx_world.c` causal crumbs; aienos `native/argus/` event ingest | Pre-R fixed-name receipts for M4-M19: historical records, kept unchanged. Not classified by the R16 map | No shared cross-repo evidence schema exists. The R16 map lists "duplicate causal state" as open: the R4 causal-trace target is not yet named |
| Cortex | omega `src/runtime/rx_cortex.{c,h}` by [ADR 0022](../docs/adr/0022-canonical-cortex-owner.md): contract, single writer (`cx_claim_writer`, exclusive journal lock) and journal; World execution enters only through `rx_cortex_record.c` | sovereign-core `crates/cortex-rs` (live Linux LLM-stack Cortex): legacy, retire not port. aienos `crates/aienos-cortex` (Rust epistemic store): legacy, retire not port. Records enter the canonical store only as `CX_K_IMPORTED` claims | Host only, one in-memory tier plus journal, L1/L2/L3 tiers not implemented, not in the R13 living-system build (built in the state-projection test and `test-cortex`), no Fabric or remote Cortex. Not in the R16 map. Owner recorded 2026-09-30 from `aien-spark/omega#114` (`43dcb04`) |
| J-Space | No authoritative owner recorded | omega `src/runtime/rx_jspace.{c,h}` host reference, built at the re-check only into the `rx_branch_reuse` test target, since omega#116 also in `test-jspace-prod` (evidence `evidence/BRANCH_REUSE`), not in the R13 living-system build. aienos `JSpaceWorld`: legacy | Missing on the production reaction path (EST-7 planned). 2026-09-30: production local-only `rx_jspace` merged (`aien-spark/omega#116`, `529ebfa`, own CI test target); remote operations return `JS_ERR_REMOTE`; still not in the R13 living-system build |
| Resource scarcity pricing (DUAL) | No owner yet: ADR 0031 records the contract; planned home omega `src/dual/` (standalone) then `src/runtime/rx_dual.{c,h}` | none. Price-like inputs today are constants: omega `rx_jspace.c` residency pressure (`1e9` / `1e3`), sovereign-core `aien-scheduler` `SchedulerConfig` limits (E), spark-rsi fixed-weight `rank_bottlenecks` | Missing. DUAL prices SOFT budgets only, never INVARIANT constraints; it orders survivors of hard gates and Pareto filtering and holds no authority (ADR 0031) |
| Standing goal source (Aien) | Aien subject object (aienos continuity kind 24, [aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md)), published through the existing external path `rx_world_publish_external` ([ADR 0035](../docs/adr/0035-persistent-cognitive-entity-boundary-aien.md) §3, §5). Previously unowned ("external, human") | none | Host and QEMU TESTED; hardware NOT_RUN; kernel production path PARTIAL (ADR 0035 §9 gate table). Aien is durable state, not a loop (I7) |
| Held-knowledge set (Aien) | Aien: references to Cortex promotion records, by digest; the records stay in Cortex (ADR 0035 §5, I5) | none | Same as above |
| Identity, Cortex journal and World subject binding (Aien) | Aien binding record (omega `src/allen/allen_bind.h: AllenBinding` (planned rename: `src/aien/aien_bind.h: AienBinding`)); the mechanisms stay with Aienux and omega (ADR 0035 §3 item 3, §5) | none | Same as above |

A concept moves to a new owner only through an accepted ADR or an R16 gate result recorded in `ROADMAP.md`.

---

## 3. Hardware Topology: The Heterogeneous Cognitive Substrate

The Sovereign Machine breaks with legacy symmetric computing and traditional coprocessor paradigms. It establishes a specialized dual-topology where CPU and GPU operate in a tightly coupled, asymmetric master-governor relationship.

This CPU+GPU dual topology is the first qualified Machine, not the definition of a Machine. Additional substrates (analog, neuromorphic, FPGA/CGRA, optical/photonic, future) attach as FORGE capability providers under ADR 0018 (ACCEPTED); they do not change what a Machine is or what Omega programs mean.

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        COHERENT UNIFIED PHYSICAL MEMORY SPACE                          │
│                                (NVLink-C2C Interconnect)                               │
│                                                                                        │
│   ┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────────────┐  │
│   │   SEMANTIC_STORE    │   │     INTENT_RING     │   │         EFFECT_RING         │  │
│   │ Immutable Graph ASTs│   │ Lock-free SPSC FIFO │   │ Verified physical acts      │  │
│   └─────────────────────┘   └─────────────────────┘   └─────────────────────────────┘  │
│   ┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────────────┐  │
│   │     RESULT_RING     │   │      PROOF_RING     │   │       EVIDENCE_STORE        │  │
│   │ Execution handles   │   │ Formal verification │   │ Telemetry & metric counters │  │
│   └─────────────────────┘   └─────────────────────┘   └─────────────────────────────┘  │
└───────────────────▲───────────────────────────────────────────────────▲────────────────┘
                    │                                                   │
     Coherent 64B Cache-Line Access                       Coherent 64B Cache-Line Access
     Hardware Acquire/Release Atomics                    Hardware Acquire/Release Atomics
                    │                                                   │
┌───────────────────┴───────────────────┐               ┌───────────────┴────────────────┐
│           AArch64 CPU HOST            │               │      BLACKWELL / HOPPER        │
│     "Trusted Physical Governor"       │               │      ACCELERATOR ENGINE        │
│                                       │               │ "Residence of Cognition"       │
│  - Runs FORGE at contract EL          │               │  - Runs Aien Core Mind         │
│  - Owns Platform MMU & SMMUv3         │               │  - Full HBM Resident Weights   │
│  - Hardware Watchdogs & Safety        │               │  - Persistent Unified KV Pool  │
│  - Checks AEGIS Invariants & Bounds   │               │  - Autonomous Tensor Pipeline  │
│  - Low-latency Ring Dispatch          │               │  - Direct SM Micro-Execution   │
└───────────────────────────────────────┘               └────────────────────────────────┘
```

### 3.1 The CPU: Trusted Physical Governor
* The CPU is not the computational workhorse; it is the **Governor**.
* It runs the bare-metal **Physics** kernel at the privileged exception level declared by the machine contract (EL1 or EL2; the current QEMU contract `CONTRACT-QEMU-VIRT-AARCH64-M2` specifies EL1).
* It holds exclusive authority over interrupt dispatch, physical timer registers, hardware security modules (TPM/HSM), bus configuration, and peripheral controllers (NVMe, Network PHY).
* It monitors the accelerator through non-maskable hardware watchdogs. If the accelerator diverges, hangs, or violates memory boundaries, the CPU resets the accelerator fabric and restores verified cognitive snapshots.

### 3.2 The GPU: Primary Residence of Persistent Cognition
* The GPU is not a transient compute device or an offload accelerator; it is the **Primary Cognitive Substrate**.
* The Aien model weights, KV memory pool, attention graphs, and inference scratchpads reside permanently in GPU High Bandwidth Memory (HBM).
* The GPU never unloads the model. It does not await foreign runtime calls; it continuously processes the unified lock-free memory rings, executing inference, autonomous thought loops, and semantic graph evaluations.

### 3.3 Zero-Copy NVLink-C2C Ring Architecture
* Legacy architectures suffer milliseconds of latency due to PCIe bottlenecks, kernel transitions, and RPC serialization (JSON, Protobuf).
* The Sovereign Machine eliminates all RPC. Communication between CPU Governor and GPU Accelerator occurs across a coherent, physical address space linked by NVLink-C2C (900 GB/s bidirectional bandwidth).
* Coordination relies strictly on **64-byte aligned, lock-free ring buffers** utilizing hardware acquire/release atomics:
  * `INTENT_RING`: CPU submits evaluated semantic requests to the accelerator.
  * `RESULT_RING`: Accelerator posts completion status and memory handles to the CPU.
  * `EFFECT_RING`: Accelerator requests real-world side effects; CPU AEGIS verifier validates capabilities and invariants before physical emission.
  * `PROOF_RING`: Verification workers audit execution traces against formal mathematical invariants.
  * `EVIDENCE_STORE`: Hardware performance telemetry (cycles, cache misses, energy) is continuously recorded for Omega's living optimization loop.

---

## 4. The Sovereign Roadmap

Milestone numbering, code identifiers, and milestone status are maintained in exactly one place: **[`ROADMAP.md`](ROADMAP.md)** (the 41-milestone M0-M40 Sovereign Roadmap, including Physics Zero M27-M35 and General AIEN M36-M40). This document does not restate the roadmap table or milestone status.

---

## 5. Operational Realities & System Principles

### 5.1 Hard Stops
The Sovereign Machine enforces six non-negotiable architectural **Hard Stops**. Any violation triggers an immediate, fail-closed system halt:
1. **No Foreign Binary Inclusion:** No precompiled x86/ARM ELF shared libraries, closed-source kernel modules, or binary blobs may execute within the sovereign boundary.
2. **No Unsigned Physical Effects:** No outbound physical action (disk block mutation, network transmission, GPIO trigger) may execute without a valid, cryptographically verified AEGIS capability token.
3. **No Foreign Weight Ingestion:** No black-box neural network checkpoints may be ingested into Aien without full cryptographic training provenance and dataset validation.
4. **No Bypass of Machine Physics Authority:** Accelerator code may never directly manipulate system MMU tables, interrupt registers, or platform power states.
5. **No Undefined Precision Divergence:** Invariant verification failure: if an Omega realization produces numerical error exceeding the defined semantic envelope ($\hat{\epsilon} > \epsilon$), execution halts immediately.
6. **No Non-Deterministic Bootstrap:** If Atlas experiences an unexpected state transition, branching anomaly, or hash mismatch, the system enters an unrecoverable low-power lock state.

### 5.2 Performance Philosophy
The performance doctrine is governed by **Mechanical Sympathy**:
* **Zero Allocation in Steady State:** Dynamic heap allocation during active cognitive cycles is strictly prohibited. All memory arenas, tensor buffers, and ring queues are pre-allocated at initialization.
* **Zero Serialization:** Data is structured in memory exactly as the consuming execution unit expects. No translation layers, JSON parsers, or marshalling code exist on the execution path.
* **Cacheline Sovereignty:** All shared data structures are aligned to 64-byte boundaries, matching hardware cache lines to eliminate false sharing and memory bus contention.
* **Latency Hiding via Pipeline Parity:** Realizations are synthesized to balance computational intensity with memory bandwidth, utilizing multi-accumulator unrolling and non-temporal streaming stores.

### 5.3 Failure Model & Fault Tolerance
* **Fail-Closed Default:** Any unexpected exception, bus error, or invariant breach fails closed. System state freezes, registers are preserved, and an alert is dispatched to the `FAULT_MAILBOX`.
* **Monotonic Degradation:** If an optimized realization $R_k$ experiences an anomaly, the dispatcher instantly falls back to the simpler, formally proven baseline realization $R_0$.
* **Hardware Watchdog Governors:** The CPU governor runs hardware watchdog timers against the GPU. Failure to acknowledge heartbeats initiates an atomic reset of the accelerator subsystem and recovery from the last verified Cortex checkpoint.

### 5.4 Architectural Metrics
Performance and sovereignty are quantified through six continuous metrics:

| Metric | Target Boundary | Description |
| :--- | :--- | :--- |
| **Time to First Token (TTFT)** | $< 12 \text{ ms}$ | Elapsed time from intent injection into `INTENT_RING` to initial cognitive output token generation. |
| **Inter-Token Latency (ITL)** | $< 4.5 \text{ ms}$ | Steady-state decode latency per token during continuous autoregressive cognitive loops. |
| **Dispatch Overhead** | $< 250 \text{ ns}$ | Latency between CPU intent post and accelerator kernel launch over NVLink-C2C. |
| **Memory Bandwidth Efficiency** | $> 88\%$ | Percentage of theoretical peak memory bandwidth achieved across sustained tensor contractions. |
| **Sovereign Code Ratio** | $100\%$ | Ratio of self-synthesized/audited machine instructions to total executed instructions. |
| **Invariant Verification Pass Rate**| $1.0000$ | Mathematical conformance of observed execution against semantic error bounds ($\hat{\epsilon} \le \epsilon$). |

---

## 6. The Defining Demonstration: 24-Step End-to-End Trace

The operational realization of the Sovereign Machine is demonstrated by a complete, continuous 24-step trace from cold silicon power-on to verified physical transformation:

```text
 PHASE I: AWAKENING (Steps 1-6)
 [1] Cold Silicon Reset ──> [2] Atlas Executes ──> [3] MMU & Cache Init ──>
 [4] SHA-256 Measure   ──> [5] Contract-EL Jump ──> [6] Atlas Terminates

 PHASE II: GOVERNANCE & RESIDENCE (Steps 7-12)
 [7] Physics Brings Up ──> [8] SMMUv3 Locks   ──> [9] NVLink-C2C Setup ──>
 [10] Rings Mapped     ──> [11] GPU Awoken    ──> [12] Weights Permanent

 PHASE III: COGNITION & INTENT (Steps 13-18)
 [13] Intent Ingested  ──> [14] G_S Decomposed──> [15] Physics Lower ──>
 [16] AEGIS Verified   ──> [17] Intent Queued ──> [18] GPU Fetches Intent

 PHASE IV: REALIZATION & CLOSURE (Steps 19-24)
 [19] Kernel Select    ──> [20] Tensor Exec   ──> [21] Error Verified  ──>
 [22] Result Published ──> [23] Evidence Sealed──> [24] Cortex Learned
```

### Detailed Trace Walkthrough:
1. **Cold Silicon Reset:** Electrical power stabilizes; CPU reset vector fetches the first instruction of `atlas.bin` from secure physical ROM.
2. **Atlas Execution:** Atlas initializes core architectural registers, clears scratchpad SRAM, and disables speculative prefetchers.
3. **MMU & Cache Initialization:** Atlas constructs minimal identity page tables (EL1/EL2) and enables the data/instruction caches.
4. **Cryptographic Measurement:** Atlas reads the Physics binary from non-volatile storage, computes its SHA-256 digest, and validates it against the platform Root of Trust.
5. **Monotonic Handoff:** Atlas transfers control to the Physics entry point under `PHYSICS_ENTRY_ABI` at the exception level declared by the machine contract, with no implicit EL2 -> EL1 transition (the current QEMU contract `CONTRACT-QEMU-VIRT-AARCH64-M2` specifies EL1).
6. **Atlas Termination:** Atlas's code space is permanently unmapped from page tables; Atlas ceases execution.
7. **Physics Bringup:** Physics establishes its core memory allocator, initializes the exception vector table, and brings up the diagnostic console.
8. **SMMUv3 Lock:** Physics configures memory protection contexts for all PCIe peripherals, locking DMA access to isolated buffers.
9. **NVLink-C2C Coherent Setup:** Physics configures the high-speed chip-to-chip coherent memory bus between AArch64 host and Blackwell GPU.
10. **Ring Buffer Mapping:** Physics pre-allocates and initializes the 64-byte aligned lock-free rings (`INTENT`, `RESULT`, `EFFECT`, `PROOF`, `EVIDENCE`).
11. **GPU Cognitive Awakening:** Physics triggers the GPU bootstrap sequence via MMIO BAR0; GPU streaming multiprocessors initialize.
12. **Weights Made Permanent:** Aien's foundation weights are mapped directly into GPU HBM3e; KV memory pools are reserved and locked.
13. **Human Intent Ingestion:** A natural or formal intent statement is submitted to the system via the local console interface.
14. **Semantic Decomposition:** Aien proposes intent; Omega defines the formal semantic graph ($\mathcal{G}_S$), specifying mathematical invariants and error bounds.
15. **Physical Lowering & Constraint Discovery:** Physics compiles the semantic program to concrete hardware state (page tables, cache flushes, GPFIFO packets, register state) and communicates hardware constraints if alternatives are required.
16. **AEGIS Invariant Verification:** Aegis inspects the requested realization against the active capability ledger, slot generations, memory bounds, and rollback paths.
17. **Intent Queued:** Physics writes the 64-byte execution descriptor to the `INTENT_RING` and executes `stlr` (Store-Release).
18. **GPU Fetches Intent:** The GPU execution engine, polling the ring head via coherent memory, fetches the descriptor with `ldar` (Load-Acquire).
19. **Realization Execution:** Hardware executes the lowered kernel variant based on active matrix dimensions and hardware telemetry.
20. **Tensor Execution:** GPU Tensor Cores execute the multi-layer neural contraction without host interrupt intervention.
21. **State Contract Verification:** Aegis verifies that execution state transitions match the formal contract and that deviations stay strictly within the semantic error envelope ($\hat{\epsilon} \le \epsilon$).
22. **Result Published:** GPU writes execution handle and cycle receipts to the `RESULT_RING` and notifies the host via atomic sequence increment.
23. **Evidence Recording:** Verified execution receipts and outcome telemetry are recorded in the immutable Evidence Ledger.
24. **Cortex Memory Integration:** The empirical execution receipt, energy consumption, and semantic outcome are committed permanently to Cortex episodic memory.

```text
================================================================================
                    THE SOVEREIGN MACHINE STANDS ESTABLISHED
================================================================================
```

