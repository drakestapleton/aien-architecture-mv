# DOCTRINE-ROADMAP: The 41-Milestone Sovereign Roadmap (M0-M40)

```text
Document ID:     DOCTRINE-ROADMAP
Classification:  Sovereign Machine Canonical Doctrine (Single Roadmap Source)
Target Substrate: Complete Sovereign Stack (Atlas -> Aienux -> AIEN / OMEGA / FORGE / AEGIS)
Status:          AUTHORITATIVE / CANONICAL
```

---

## 1. Authority of This Document

This file is the **single authoritative source** for Sovereign Machine milestone numbering, milestone code identifiers, and milestone status.

- Every other doctrine page references this file instead of restating the milestone table or milestone status.
- Milestone status is changed **only** here. A status change must cite the qualifying evidence (issue, PR, or receipt).
- `tools/doctrine/doctrine.om` (the `doctrine` gate step) enforces this: it fails if another doctrine page duplicates the roadmap table, carries its own milestone status tags, or cites a milestone code identifier under a milestone number different from the one below.

> **Historical naming rule:** ADR 0014 renames the current machine-realization subsystem to **FORGE**. Existing milestone identifiers such as `PHYSICS_BOOT`, `PHYSICS_EFFECTS`, and `PHYSICS_ACCELERATOR_LINK` remain unchanged because milestone/evidence identity is historical provenance.

Status vocabulary:

| Status | Meaning |
| :--- | :--- |
| `COMPLETE` | Milestone gate passed and ratified. |
| `COMPLETE / QEMU QUALIFIED` | Gate passed under QEMU qualification; native hardware qualification remains separately gated. |
| `REOPENED / IN PROGRESS` | Previously reported complete; reopened for requalification. Not complete. |
| `PLANNED` | Not started. |

Note (2026-10-01, Lane 33): rows M20, M22 and M23 stay `PLANNED` because no exit gate is met, but precursor work has merged for each (M20 draft `aien-spark/omega#136` open; M22 substrate `#140`; M23 corpus `#122`). For these rows `PLANNED` means "no gate met, precursor work merged", not "nothing started"; see their notes in §3.

---

## 2. The Canonical Roadmap Table

| Milestone | Era | Code Identifier | Scope & Objective Invariants | Status |
| :--- | :--- | :--- | :--- | :--- |
| **M0** | Foundational | `DOCTRINE_V1` | Foundational Specification. Ratification of complete architectural corpus. | COMPLETE |
| **M1** | Foundational | `ATLAS_BOOT` | Irreducible bootstrap seed (`atlas.bin`). Dual-seam verified. | COMPLETE / QEMU QUALIFIED |
| **M2** | Foundational | `PHYSICS_BOOT` | Physical machine authority nucleus (`physics.bin`). Current-EL VBAR, frame authority, CAP_ROOT. Requalified 2026-09-26 (`aien-spark/physics#3`, receipt `qualification_receipt.json`). QEMU only; `PHYSICS_BOOT_NATIVE_PASS` pending. | COMPLETE / QEMU QUALIFIED |
| **M3** | Foundational | `PHYSICS_EFFECTS` | Capability ledger, monotonic attenuation, effect broker, signed execution receipts (`EFFECT_INTENT` admission, `EFFECT_RECEIPT` accounting). Qualified 2026-09-26 under `aien-spark/physics#9` (commit `766f8fd6...`, receipt commit `a7dc4ef7...`). QEMU only; native hardware qualification remains separately gated. | COMPLETE / QEMU QUALIFIED |
| **M4** | Omega Core Substrate | `OMEGA_SEMANTICS` | Semantic graph ($G_S$), typed AST, invariant envelopes, substrate-independent content-addressed identity. Qualified 2026-09-26 under `aien-spark/omega` (commit `30bb116...`, receipt commit `a975573...`). | COMPLETE |
| **M5** | Omega Core Substrate | `OMEGA_AARCH64` | Native direct AArch64 machine byte realization generator (no LLVM). Qualified 2026-09-26 under `aien-spark/omega` (commit `2dd4102...`, receipt commit `34dbe93...`). | COMPLETE |
| **M6** | Omega Core Substrate | `OMEGA_SELF_HOST` | Closed-loop reproduction check of a fixed realization emitter (`OMEGA_SELF_HOST`). Qualified 2026-09-26 under `aien-spark/omega` (commit `8033c38...`, receipt `evidence/omega_self_host_qualification_receipt.json`). Correction 2026-09-30: the gates proved a fixed-output self-copy fixed point, not compilation; M6 is not evidence of a general Omega compiler (see §3 M6 note). | COMPLETE |
| **M7** | Omega Core Substrate | `OMEGA_VERIFY` | Mandatory V0-V2 verification engine; V3-V5 proof-carrying code framework. Qualified 2026-09-26 under `aien-spark/omega` (commit `202fa3c...`, receipt `evidence/omega_verify_qualification_receipt.json`). | COMPLETE |
| **M8** | Program Synthesis & Library Learning | `OMEGA_PROGRAM_CORE` | Explicit program representation, synthesis task schema (`SYNTHESIS_TASK`), program cost modeling. Qualified 2026-09-26 under `aien-spark/omega` (commit `d25349e...`, receipt `evidence/omega_program_core_qualification_receipt.json`). | COMPLETE |
| **M9** | Program Synthesis & Library Learning | `OMEGA_SYNTHESIS_V0` | Deterministic typed program synthesis over base primitives. Qualified 2026-09-26 under `aien-spark/omega` (commit `39905a3...`, receipt `evidence/omega_synthesis_v0_qualification_receipt.json`). | COMPLETE |
| **M10** | Program Synthesis & Library Learning | `OMEGA_LIBRARY_V1` | Versioned procedural program library, provenance tracking, and verified component catalog. Qualified 2026-09-26 under `aien-spark/omega` (commit `1808ed8...`, receipt commit `d3ac970...`). | COMPLETE |
| **M11** | Program Synthesis & Library Learning | `OMEGA_LIBRARY_DISCOVERY` | Autonomous abstraction discovery from program corpus with verified reuse. Qualified 2026-09-26 under `aien-spark/omega` (commit `1ee43fb...`, receipt commit `8e0a50a...`). | COMPLETE |
| **M12** | Program Synthesis & Library Learning | `OMEGA_LIVING_MATVEC` | Adaptive realization selection across varying input regimes and cache dynamics. Qualified 2026-09-26 under `aien-spark/omega` (commit `44f645f...`, receipt commit `5a22e60...`). | COMPLETE |
| **M13** | Program Synthesis & Library Learning | `OMEGA_MACHINE_GRAPH` | Formal machine hardware graph ($G_M$) describing execution pipelines and memory hierarchies, as reported by Physics. Qualified 2026-09-26 under `aien-spark/omega` (commit `9413558...`, receipt commit `db066d9...`). | COMPLETE |
| **M14** | Program Synthesis & Library Learning | `OMEGA_REALIZATION_SYNTHESIS` | Automated $G_S \times G_M \to G_R$ synthesis targeting declared hardware capabilities. Qualified 2026-09-26 under `aien-spark/omega` (commit `c0c8102...`, receipt commit `03fbcb9...`). | COMPLETE |
| **M15** | Accelerator Cognition Substrate | `PHYSICS_ACCELERATOR_LINK` | Bounded accelerator authority model grounded in observed DGX Spark device, coherent-memory, SMMUv3, IOMMU, and BAR topology. Native Blackwell submission protocol intentionally deferred to M16. Qualified 2026-09-26 under `aien-spark/physics` and `aien-spark/omega`. | COMPLETE / HARDWARE BOUNDARY QUALIFIED |
| **M16** | Accelerator Cognition Substrate | `BLACKWELL_NATIVE_PATH_KNOWN` | Empirical execution characterization of native Blackwell GB10 submission architecture (MMIO, GPFIFO queues, doorbells, completions). Correctively requalified 2026-09-26 under `aien-spark/physics` without libcuda (implementation `a2c0d7f...`, receipt `evidence/m16-blackwell-native-path-requalification-receipt.json`, canonical `b64753d...`). | COMPLETE / CORRECTIVELY REQUALIFIED |
| **M17** | Accelerator Cognition Substrate | `OMEGA_BLACKWELL_VECTOR` | Verified native Blackwell sm_121 vector compute realization bound to the $G_S$ semantic contract, using a canonical verified machine-code artifact and dynamically synthesized QMD, parameter bindings, and native submission. Qualified on physical DGX Spark GB10 silicon under `aien-spark/omega` (implementation `27971cd`, receipt `43f725e`). | COMPLETE / SILICON QUALIFIED |
| **M18** | Accelerator Cognition Substrate | `OMEGA_BLACKWELL_MATMUL` | Verified native Blackwell tensor matrix multiplication with dynamic sm_121 code generation and tensor core acceleration. Qualified on physical DGX Spark GB10 silicon under `aien-spark/omega` (implementation `9421737`, receipt `87349c0`). | COMPLETE / SILICON QUALIFIED |
| **M19** | Accelerator Cognition Substrate | `OMEGA_ACCELERATOR_RESIDENT` | Persistent Omega execution substrate residing in accelerator-accessible coherent memory. Implementation `beaa1185154051f147a5588e9fa78410a879b9a1`, evidence `5a850796c6e0e843178ade5374034066539d4697`, merge `ae2476d2c16beedff6507cbfc36701bb740203de`, authority substrate `aien-spark/physics` (`b64753d95bacb1114ba48decde48239f0c542e12`). Reopened per errata E-M19-1..10; requalified and closed 2026-09-30 via M19R Gate 14 Combined Foundation Admission (`evidence/GATE14-FOUNDATION/50dd611bfd28e8320443810b35f7425df5eb112777662e5840c227154271f872.json`, `aien-spark/omega#111`) on clean Omega `8024e9a` + Physics `e95e3ed`. | COMPLETE / CORRECTIVELY REQUALIFIED |
| **M20** | Sovereign Training Runtime | `OMEGA_TENSOR` | Tensor semantics, multi-dimensional array types, strides, and memory layouts. | PLANNED |
| **M21** | Sovereign Training Runtime | `OMEGA_AUTODIFF` | Sovereign automatic differentiation generating gradient semantic graphs. | PLANNED |
| **M22** | Sovereign Training Runtime | `OMEGA_OPTIMIZER` | Verified sovereign optimizer realizations (SGD, Adam, AdamW). | PLANNED |
| **M23** | Sovereign Training Runtime | `OMEGA_SEARCH_GUIDE_TRAINING` | Sovereign training pipeline for search guides using Omega-generated traces. | PLANNED |
| **M24** | Sovereign Training Runtime | `AIEN_0` | First sovereign neural search guide ranking subgoals and pruning search branches. | PLANNED |
| **M25** | Sovereign Training Runtime | `AIEN_GUIDED_SYNTHESIS` | Neural-guided synthesis achieving lower search cost under invariant verification parity. | PLANNED |
| **M26** | Sovereign Training Runtime | `AIEN_ABSTRACTION_DISCOVERY` | AIEN proposes candidate abstractions; Omega enforces survival based on utility. | PLANNED |
| **M27** | Physics Zero Discovery | `PHYSICS_ZERO_PROTOCOL` | Contamination firewall specification and sealed evaluation benchmark contracts. | PLANNED |
| **M28** | Physics Zero Discovery | `PHYSICS_ZERO_HIDDEN_WORLDS` | Discrete and continuous sealed benchmark worlds with randomized channels (P0-0..P0-2). | PLANNED |
| **M29** | Physics Zero Discovery | `AIEN_THEORY_DISCOVERY` | Executable `OMEGA_THEORY` synthesis, population competition, and calibrated prediction. | PLANNED |
| **M30** | Physics Zero Discovery | `AIEN_ACTIVE_EXPERIMENTATION` | Active experiment design distinguishing competing theories ($P(R \mid A) \neq P(R \mid B)$). | PLANNED |
| **M31** | Physics Zero Discovery | `AIEN_CONCEPT_FORMATION` | Autonomous invention of reusable latent concepts (`OMEGA_DISCOVERED_CONCEPT`). | PLANNED |
| **M32** | Physics Zero Discovery | `PHYSICS_ZERO_ALIEN_WORLDS` | Scientific discovery in universes governed by unfamiliar laws (P0-5). | PLANNED |
| **M33** | Physics Zero Discovery | `PHYSICS_ZERO_NOVEL_REGIME` | Extrapolative theory prediction in unobserved state regimes. | PLANNED |
| **M34** | Physics Zero Discovery | `PHYSICS_ZERO_NOVEL_PHENOMENON` | Predictive discovery and experimental realization of unobserved phenomena. | PLANNED |
| **M35** | Physics Zero Discovery | `PHYSICS_ZERO_REAL_LAB` | Capability-bounded, safety-governed autonomous discovery in physical laboratories. | PLANNED |
| **M36** | General AIEN | `AIEN_HUMAN_INTERFACE` | Bi-directional perceptual adapter mapping human natural language to Omega semantics. | PLANNED |
| **M37** | General AIEN | `AIEN_RESIDENT` | Persistent, high-throughput cognitive loop resident in accelerator HBM memory. | PLANNED |
| **M38** | General AIEN | `OMEGA_CONTINUAL_LIBRARY_LEARNING` | Continuous Wake/Solve/Verify/Sleep compounding loop. | PLANNED |
| **M39** | General AIEN | `AIEN_SCIENTIFIC_AUTONOMY` | Fully autonomous scientific discovery cycle: observe, hypothesize, test, discover. | PLANNED |
| **M40** | General AIEN | `AIEN_SUCCESSION` | Sovereign succession protocol: AIEN-N trains and proposes AIEN-N+1 candidate. | PLANNED |

Era ranges: Foundational M0-M3; Omega Core Substrate M4-M7; Program Synthesis & Library Learning M8-M14; Accelerator Cognition Substrate M15-M19; Sovereign Training Runtime M20-M26; **Physics Zero Discovery M27-M35**; **General AIEN M36-M40**.

---

## 3. Milestone Notes & Evidence

### M1 — `ATLAS_BOOT`
- Repository: https://github.com/aien-dev/atlas
- Canonical Artifact: `atlas.bin` (1,480 bytes, SHA-256: `f7802501b410a0c19eff7b8fca8865c9ba9c96bfa4f8065ca8f508b67748b9a5`)
- Dual-Seam Verification:
  - Seam 1 (Static Audit): 100% word-reconciled (301 insns, 69 rodata words, 0 discrepancy), static target proof (`ldr x19, =0x40200000; br x19`), disjoint stack/descriptor proof (SP <= `0x401FC000` vs Descriptor @ `0x401FE000` with 8 KiB guard gap, empty intersection).
  - Seam 2 (Execution Harness): Bare-metal QEMU virt; 268/268 mutations refused into fail-closed quiescence (exhaustive 256 single-byte offset sweep + 12 adversarial scenarios).
  - Cryptographic Scheme: Bare-metal NIST FIPS 180-4 SHA-256 (KAT verified 100%).
- Native Hardware Status: `ATLAS_BOOT_NATIVE_PASS` remains pending and decoupled from QEMU qualification.
- Specification: [`docs/milestone-1-spec.md`](../docs/milestone-1-spec.md).

### M2 — `PHYSICS_BOOT`
- Requalified 2026-09-26 under aien-spark/aien-architecture#6, aien-spark/physics#1, and aien-spark/physics#3 (descriptor ingress anti-expansion, frame authority bounds, and exception confinement hardening). Ratified via qualification receipt (`qualification_receipt.json`).
- Exception level is contract-driven: Physics checks `CurrentEL` against the machine contract and installs `VBAR_EL1` or `VBAR_EL2` accordingly, with no implicit EL2 -> EL1 transition. The current QEMU contract, `CONTRACT-QEMU-VIRT-AARCH64-M2`, specifies EL1 entry.
- `PHYSICS_BOOT_QEMU_PASS` does not imply `PHYSICS_BOOT_NATIVE_PASS`.
- Specification: [`docs/milestone-2-spec.md`](../docs/milestone-2-spec.md).

### M3 — `PHYSICS_EFFECTS`
- Qualified 2026-09-26 under `aien-spark/physics#9` (merged as commit `766f8fd6b898f4df793ffa809f031040ba0912fa`), ratified via qualification receipt `m3/m3_qualification_receipt.json` in commit `a7dc4ef7e0ea9fa733d06114eb31a26d70cb3e53`.
- Bounded 32-record capability ledger with monotonic attenuation, ancestor-chain validation on use (instantaneous descendant revocation), single canonical effect broker with 10-stage fail-closed admission decoupled from physical handlers, append-only receipt ledger with rolling cryptographic SHA-256 seal chain, and 32-entry replay cache.
- In-guest bare-metal test suite in QEMU virt AArch64 passed 21/21 tests (`0x001FFFFF`). Python-free qualification runner evaluated all 19 canonical gates with 100% pass and zero regressions on M1 or M2.
- Anti-bloat budget: `physics.elf` text size 10,624 bytes (32.4% of 32 KiB budget); `physics.bin` total image 18,432 bytes (28.1% of 64 KiB budget).
- Native Hardware Status: QEMU qualified only; native hardware qualification remains separately gated.
- Specification: [`docs/milestone-3-spec.md`](../docs/milestone-3-spec.md).

### M5 — `OMEGA_AARCH64`
- Name note (2026-10-08): this is Omega M5. `CURRENT_EXECUTION_PLAN.md` also says "M5" for the Aienux encryption and identity milestone (TRUST-1); that is a different milestone.
- Qualified 2026-09-26 under `aien-spark/omega` (commit `2dd41024345d207d57f59d4c7940176b6697b099`, receipt commit `34dbe93e9fa22aee50b8eb426e6d1e43444490f2`).
- Direct AArch64 machine byte realization generator without LLVM, Clang, GCC, or GNU `as`.
- Verified pure integer register lowering ($G_S \to$ AArch64) for $F(a, b, c) = (a + b) - c$.
- Content-addressed `REALIZATION_ID` cryptographic binding to M4 `SEMANTIC_ID`.
- Triple verification seams:
  1. Static independent instruction bitmask decoder.
  2. Native DGX Spark in-memory execution (`mprotect PROT_EXEC`).
  3. Bare-metal QEMU virt runner execution with PL011 UART telemetry and semihosting clean exit.
  4. Adversarial single-bit mutation refusal gate.
- 9/9 canonical M5 qualification gates passed. Specification: [`docs/milestone-5-spec.md`](../docs/milestone-5-spec.md).

### M6: `OMEGA_SELF_HOST` (correction note, 2026-09-30)
- The historical identifier, commit `8033c38`, receipt `evidence/omega_self_host_qualification_receipt.json` and the COMPLETE row above are kept unchanged. The 10 M6 gates as specified did pass.
- What the gates actually proved: the emitted "compiler" (`src/omega_self_host.c`, `emit_compiler_code`) checks the `OMGG` header, then dispatches on the object-count byte. For the 8-object graph $G_S$ it writes three constant words (ADD, SUB, RET). For the 5-object graph $G_C$ it copies its own instruction bytes. So `C1 == C2 == C3` holds by self-copy (quine style), not by compiling $G_C$.
- M6 is therefore **not** evidence of a general Omega compiler or of compiler self-hosting, and it does not satisfy `SOVEREIGNTY.md` §6.3 invariant 1. At the correction's 2026-09-30 source pin, omega main had no general compiler: `omega_program_realize` (`src/omega_program.c`) lowered one arithmetic/bitwise program-body shape to AArch64; the surface-language front end (`src/language/`) was partial. The 2026-10-01 OSC-1 (`aien-spark/omega#144` `b81f850`) and OSC-2 (`#148` to `#151`, last `7e713e3`) slices were IMPLEMENTED / NOT QUALIFIED with host receipts. Those historical results remain separate from later compiler work.
- Source of this correction (omega main `6d1ff1d`): `spec/self-host.md` note of 2026-09-29; `docs/adr/OMEGA-SYSTEMS-CORE-0000.md` item C8 (decided by Drake Stapleton, 2026-09-29: the M6 result "was a fixed-output self-copy check, not compilation, and is never evidence of a compiler"); `docs/osc/audit/language-compiler.md`.
- Reopening M6 or redefining its gate is an explicit decision that has not been taken. Until then the row stays COMPLETE with this note.
- Current compiler status (2026-10-26): omega-mv main includes the seeded `.om` compiler (`seed/omc/omc.om` and `seed/out/omc`), landed via [PR #696](https://github.com/aien-dev/omega-mv/pull/696); see [omega-mv README](https://github.com/aien-dev/omega-mv/blob/ec07d25d5506d33567adbd4d9b518177b7933bad/README.md). This does **not** retroactively qualify M6 as compiler self-hosting, nor establish untested compiler capabilities.

### M7 — `OMEGA_VERIFY`
- REQUIRED: V0 Structural/Type/Capability, V1 Differential, V2 Property/Invariant.
- FRAMEWORK DEFINED FOR: V3 Adversarial, V4 Symbolic, V5 Proof-Carrying.

### M11 — `OMEGA_LIBRARY_DISCOVERY`
One nontrivial abstraction not present in the initial library that:
1. Compresses multiple verified programs;
2. Preserves their semantics;
3. Is reused on held-out tasks;
4. Reduces search cost.

### M12 — `OMEGA_LIVING_MATVEC`
- Qualified 2026-09-26 under `aien-spark/omega` (commit `44f645f176f634fdb4b5aac950d31423b2946664`, receipt commit `5a22e60458c0545f6facbd6063b1209a4fc85b52`).
- Pure mathematical Matrix-Vector multiplication specification ($y = Ax$, contract `CONTRACT-OMEGA-LIVING-MATVEC-M12`) without hardware commitment.
- Machine-aware synthesis generating 3 distinct candidate AArch64 realizations targeting MachineGraph ($G_M$):
  - $R_0$: `matvec_scalar` (18 insns, 72 bytes)
  - $R_1$: `matvec_unroll2` (31 insns, 124 bytes)
  - $R_2$: `matvec_unroll4_dual` (44 insns, 176 bytes, dual ALU accumulators targeting 4-wide Neoverse V2 dispatch)
- Cryptographic triple identity binding: `REALIZATION_ID = SHA-256(OMG0 | KIND_REALIZATION | profile | entry_offset | code_len | SEMANTIC_ID | MACHINE_ID | code_bytes)`.
- Verification ladder: V0 structural verification and V1 differential numerical parity ($\hat{\epsilon} = 0$) against mathematical Oracle.
- Living kernel discovers cache-tier inflection points and adaptively dispatches optimal realization, achieving 1.15x–1.20x measured speedup on DGX Spark.
- Zero foreign toolchain: 0 LLVM, 0 GNU as, 0 GCC inline asm, 0 JIT, 0 Python.
- 10/10 canonical M12 qualification gates passed (111/111 cumulative gates across M4–M14 with zero regressions).
- Specification: [`docs/milestone-12-spec.md`](../docs/milestone-12-spec.md).

### M14 — `OMEGA_REALIZATION_SYNTHESIS`
- Qualified 2026-09-26 under `aien-spark/omega` (commit `c0c8102ecc7f36cb86ab8686e5f1ee08eb59762d`, receipt commit `03fbcb9`).
- Automated machine-aware lowering synthesis ($G_S \times G_M \to G_R$) producing verified native AArch64 machine code without LLVM, GCC, GNU `as`, or JIT.
- Cryptographic triple identity binding: `REALIZATION_ID = SHA-256(OMG0 | KIND_REALIZATION | profile | entry_offset | code_len | SEMANTIC_ID | MACHINE_ID | code_bytes)`.
- Machine-aware instruction scheduling specialized for DGX Spark Grace Neoverse V2 (4-wide issue, multi-register pre-load) vs QEMU virt (2-wide baseline sequential).
- 10/10 canonical M14 qualification gates passed (101/101 cumulative gates across M4-M14 with zero regressions).
- Specification: [`docs/milestone-14-spec.md`](../docs/milestone-14-spec.md).

### M15 — `PHYSICS_ACCELERATOR_LINK`
- Status: **COMPLETE / HARDWARE BOUNDARY QUALIFIED**.
- Qualified 2026-09-26 under `aien-spark/physics#10` and `aien-spark/omega#21`.
- Grounded in observed DGX Spark physical topology: NVIDIA GB10 (`10de:2e12` @ `000f:01:00.0`, IOMMU group 20), ARM SMMUv3 (`arm-smmu-v3.1.auto` @ `0x13000000`, Stream ID `0x0100`), BAR0 aperture `0x24000000-0x27ffffff` (64 MiB), within 128 GiB unified coherent LPDDR5x DRAM `[0x80000000, 0x2080000000)`.
- Canonical Boundary Principle:
  - M15 establishes who may touch the accelerator (authority model & topology grounding).
  - M16 discovers how the accelerator is actually commanded (empirical submission path discovery).
  - Native Blackwell submission mechanics intentionally deferred to M16; 0 guessed MMIO writes performed.
- Subsystem ownership boundaries recorded: Linux kernel/driver holds active hardware programming; Physics holds sovereign authority model; bare-metal takeover deferred.
- Dual-substrate qualification:
  - **Physics Substrate**: 10/10 canonical qualification gates passed (including `PHYSICS_ACCEL_HARDWARE_BOUNDARY_PASS`, `PHYSICS_ACCEL_ZERO_RUNTIME_DEP_PASS`).
  - **Omega Substrate**: 10/10 canonical M15 gates passed (121/121 cumulative gates across M4–M15 with zero regressions). Unkeyed rolling SHA-256 digest chain integrity verified. Dynamic `UNIT_ACCELERATOR_PORT` injection and canonical `MACHINE_ID` recalculation qualified.
- M16 Dependency Satisfied: Milestone 16 (`BLACKWELL_NATIVE_PATH_KNOWN`) unblocked from a truthful, verified foundation.
- Specification: [`docs/milestone-15-spec.md`](../docs/milestone-15-spec.md).
- Hardware Audit: [`docs/research/dgx-spark-hardware-audit-m15.md`](../docs/research/dgx-spark-hardware-audit-m15.md).

### M16 - `BLACKWELL_NATIVE_PATH_KNOWN`
- Status: **COMPLETE / CORRECTIVELY REQUALIFIED**.
- Requalified 2026-09-26 under `aien-spark/physics`:
  - Implementation Commit: `physics@a2c0d7fbc03f7ce91fcb6389312a0ee8630322cd`
  - Requalification Receipt Commit: `physics@92038f7`
  - Canonical Main Commit: `physics@b64753d95bacb1114ba48decde48239f0c542e12` (PR #11)
  - Requalification Receipt: `physics/evidence/m16-blackwell-native-path-requalification-receipt.json`
  - Audit Dossier: `physics/evidence/m16-requalification/M16_REQUALIFICATION_AUDIT.md`
- Historical Original Qualification:
  - Original Commit: `physics@f72e2974793a288c5dd910180f4685deffa31bb7`
  - Original Receipt: `physics/evidence/m16-blackwell-native-path-receipt.json`
  - Status: **SUPERSEDED / FAILED INDEPENDENT RUNTIME AUDIT**
  - Historical Record: Retained in git history as an immutable audit record. The original harness linked and loaded `libcuda.so.1`, called CUDA initialization APIs (`cuInit`, `cuStreamCreate`), and reused session-specific queue addresses.
- Grounded on live DGX Spark hardware without libcuda:
  - Hardware: NVIDIA GB10 (Grace Blackwell, sm_121 / 0xa04), GPU ID `0xf0100`, bus `0000000f:01:00.0`.
  - Zero Foreign Userspace Runtime: `ldd`, `nm -u`, and `/proc/$PID/maps` verified zero `libcuda`, `libcudart`, or `libnvidia` dependencies. Linked strictly against standard C library (`libc.so.6`).
  - Native Resource Allocation: Raw ioctls on `/dev/nvidiactl`, `/dev/nvidia0`, and `/dev/nvidia-uvm` dynamically allocate client, device, subdevice, memory, and channel resources.
  - Usermode doorbell aperture: class `0xC661` (`HOPPER_USERMODE_A`) at BAR0 offset `0xbb0000` (`0x24bb0000`), register offset `+0x90` (`NVC361_NOTIFY_CHANNEL_PENDING`).
  - GPFIFO format: 1,024 8-byte entries per channel; bit 41 (`LEVEL_SUBROUTINE`) pushbuffer dispatch.
  - Pushbuffer command stream: `NVC06F_DMA_SEC_OP_INC_METHOD` packets (`SET_OBJECT` method `0x000` to `BLACKWELL_COMPUTE_B` `0xcec0`, `SEM_ADDR_LO` method `0x5c`).
  - Completion attribution: pushbuffer method `0x5c` (`SEM_ADDR_LO`) writing coherent memory marker with `RELEASE` (`0x1`) flanked by `MEM_OP_D` flushes, polled directly by CPU across NVLink-C2C.
  - Causality proven: 5/5 consecutive trials demonstrate that withholding the doorbell store strictly prevents execution (marker remains 0x0), while issuing the store immediately triggers completion (marker transitions to target value).
  - Concurrency verified: Independent contexts execute concurrently without memory collision or crosstalk.
- Raw evidence bundle sealed under `physics/evidence/m16-requalification/` (with `SHA256SUMS`).
- Specification: [`docs/milestone-16-spec.md`](../docs/milestone-16-spec.md).

### M17: `OMEGA_BLACKWELL_VECTOR`
- Status: **COMPLETE / SILICON QUALIFIED**.
- Formally ratified 2026-09-26.
- Implementation: `aien-spark/omega@27971cd` (PR #22).
- Final Evidence Receipt: `aien-spark/omega@43f725e` (PR #23, `evidence/omega_blackwell_vector_qualification_receipt.json`).
- M16 Authority Substrate: `aien-spark/physics@b64753d` (PR #11).
- Specification: [`docs/milestone-17-spec.md`](../docs/milestone-17-spec.md).
- Silicon Target: NVIDIA DGX Spark, Grace Blackwell GB10 (sm_121, 128 GiB unified LPDDR5x RAM).
- Semantic Contract: Unsigned 32-bit vector addition ($C[i] = (A[i] + B[i]) \pmod{2^{32}}$) with exact bit-for-bit mathematical parity against OMEGA semantic oracle across boundary lengths $N \in \{1, 15, 63, 64, 65, 127, 128, 256, 1024\}$.
- Four-Component Realization Identity: $\text{SHA-256}(\text{spec\_id} \parallel \text{machine\_id} \parallel \text{code\_digest} \parallel \text{sm\_arch})$ uniquely locking semantic operation, machine graph, machine code artifact, and GPU SM microarchitecture.
- Qualification Gates: 18 / 18 Milestone 17 qualification gates passed.
- Cumulative Regression Accounting: 121 / 121 regression gates across prior milestones (M4 through M15) passed. Total 139 gates evaluated and passed (zero failures, zero regressions).
- Zero Foreign Userspace Runtime: Zero dynamic linkage to `libcuda.so` or `libcudart.so` (`ldd`), zero undefined dynamic CUDA symbols (`nm -u`), zero runtime mappings in `/proc/self/maps`.
- Clean-Clone Reproduction: Verified from scratch on DGX Spark silicon in isolated clone `/tmp/omega-clean-m17`.
- Cortex Receipt: Space `atlas-memory`, receipt ID `dea831e3-33c8-480c-bff3-2f170bf9b3b0`.

### M18: `OMEGA_BLACKWELL_MATMUL`
- Status: **COMPLETE / SILICON QUALIFIED**.
- Ratified 2026-09-26.
- Implementation: `aien-spark/omega` (commit `9421737`, receipt commit `87349c0`).
- Authority Substrate: `aien-spark/physics` M16 native submission (commit `b64753d`).
- Hardware Target: NVIDIA DGX Spark, Grace Blackwell GB10 (`sm_121`, 128 GiB unified LPDDR5x RAM).
- Code Truth Doctrine: Zero static precompiled instruction tables in codegen core; dynamic sm_121 instruction selection, bounded linear-scan register allocation, 128-bit machine word encoding, and QMD launch descriptor synthesis.
- Tensor Core Acceleration: Native physical GB10 execution of `HMMA.16816.F32` (FP16 inputs) and `HMMA.16816.F32.BF16` (BF16 inputs) with FP32 accumulation.
- 9-Point Proof Bundle: (1) OMEGA IR HMMA node, (2) Quad/pair bounded regalloc trace, (3) Emitted 128-bit machine words, (4) Research-oracle instruction decode, (5) Runtime SHA-256 code digest, (6) Physical GB10 completion marker `0x44444444` and semaphore `6`, (7) FP32 numerical parity within bound (< 10^-4), (8) Controlled mutation test proving divergence/refusal, (9) Zero-libcuda runtime audit.
- Qualification Gates: 18 / 18 Milestone 18 gates passed + 139 / 139 cumulative regression gates (M4 through M17) passed. Total evaluated: 157 gates passing.
- Zero Foreign Userspace Runtime: Zero dynamic linkage to `libcuda.so` or `libcudart.so` (`ldd`), zero undefined dynamic CUDA symbols (`nm -u`), zero runtime mappings in `/proc/self/maps`.
- Clean-Clone Reproduction: Verified from scratch on DGX Spark silicon in isolated clone `/tmp/omega_clean_m18`.
- Cortex Receipt: Space `atlas-memory`, receipt ID `03c34210-4ecc-4c79-9bf9-c3ac37e157f8`.

### M19: `OMEGA_ACCELERATOR_RESIDENT`
- Status: **COMPLETE / CORRECTIVELY REQUALIFIED** (closed 2026-09-30 via M19R Gate 14, `aien-spark/omega#111` `5517d22`, receipt `50dd611b...`; previously recorded here as **REOPENED / IN PROGRESS** while the M19R recovery program ran).
- Specification: `docs/milestone-19-spec.md`.
- Target Substrate: Persistent Omega Execution Substrate in Coherent Memory on NVIDIA DGX Spark (Grace Blackwell GB10, `sm_121`, 128 GiB unified LPDDR5x RAM).
- Authority Substrate: `aien-spark/physics` M16 native submission (commit `b64753d`), `aien-spark/omega` M18 (commit `7273c37`).
- Architecture: `OmegaAcceleratorWorld` holding persistent RM client, GPU device object, VAS aperture, GPFIFO compute channel, USERD doorbell mapping, completion semaphore ring, code registry, buffer registry, and coherent scratch arena.
- Core Invariant: `resident != immortal`. Every resident object requires explicit monotonic generation counters, capability-bounded access scopes, fail-closed stale handle refusal, deterministic capability revocation, and clean zero-leak teardown.
- Heterogeneous Workload: Sustained alternating execution across Vector Addition, INT32 MatMul, FP16 Tensor MMA, and BF16 Tensor MMA on the shared persistent channel.
- Queue Wraparound: GPFIFO pushbuffer ring circular wraparound verified without channel stalls, race conditions, or pushbuffer corruption.
- Sustained Execution Target: >= 1,000 heterogeneous operations executed without context teardown or re-initialization, with bounded resident memory consumption.
- Qualification Gates: 18 Milestone 19 gates + 157 cumulative regression gates (M4 through M18) = 175 total evaluated gates.
- Zero Foreign Userspace Runtime: Zero dynamic linkage to `libcuda.so` or `libcudart.so` (`ldd`), zero undefined dynamic CUDA symbols (`nm -u`), zero runtime mappings in `/proc/self/maps`.
- Ratification binding: implementation `beaa1185154051f147a5588e9fa78410a879b9a1`, evidence `5a850796c6e0e843178ade5374034066539d4697`, merge `ae2476d2c16beedff6507cbfc36701bb740203de`, physics authority `b64753d95bacb1114ba48decde48239f0c542e12`.
- Independent rerun (2026-09-27, DGX Spark): all 175 gates (M4-M19) re-executed and passed at `omega ae2476d`, with binary SHA-256, manifest digest, and rolling state digest reproduced byte-for-byte against the committed receipt. The M19 receipt's `157`/`175` counts were asserted literals at qualification time; this independent rerun corroborates that the underlying gates did pass on silicon.
- Naming: the machine realization subsystem is renamed FORGE per ADR 0014 ("FORGE REALIZES; AEGIS VERIFIES"). This is not a history rewrite: M19's own artifacts (`aien-spark/physics` M16 commit `b64753d`), the `is_physics_authorized` field serialized in historical fingerprints, and identifiers such as `PHYSICS_ACCELERATOR_LINK` keep their historical names.
- Substrate-neutral realization (analog, neuromorphic, FPGA/CGRA, photonic, future substrates) is ADR 0018 (ARCH-0018, ACCEPTED, merged 641bd3c); its workstream gates AR0-AR7 are sequenced in `CURRENT_EXECUTION_PLAN.md` §6 C3 and carry no M-number.
- Reopened: errata E-M19-1 through E-M19-10 are recorded in `docs/errata/m19-errata.md`, mapping each gap the receipt did not derive or enforce to the M19R recovery gate that closes it. M19 re-closed on 2026-09-30 via the M19R Combined Foundation Admission Gate (`docs/m19r-recovery-program.md`, `evidence/GATE14-FOUNDATION/50dd611bfd28e8320443810b35f7425df5eb112777662e5840c227154271f872.json`, `aien-spark/omega#111`).

### M19R: `FOUNDATION_REPAIR`
- Status: **PASS / CLOSED** (reclosed foundation 2026-09-30 via Gate 14 receipt `50dd611b...`).
- Specification: `docs/m19r-recovery-program.md`.
- Objective: repair the M19 qualification substrate (truthful evidence, GPU memory lifecycle, FORGE-realize/AEGIS-verify seam, observed hardware identity, FP32 machine vocabulary) before any Sovereign Training Runtime milestone (M20 onward) is qualified on top of it. (The FORGE-realize/AEGIS-verify seam is a hardware realization seam, not a stage of accepting a reaction result; ADR 0016 Amendment 1, 2026-10-02.)
- Gate: the Combined Foundation Admission Gate in `docs/m19r-recovery-program.md` covers only the foundation (evidence, runtime lifecycle, realize/verify seam, hardware identity, FP32 substrate). M19 re-closes, and M20 (`OMEGA_TENSOR`) opens, only after that foundation admission gate passes; M20-M24 remain separately qualified milestones, each with its own gate and receipt.
- Gate progress (as of 2026-09-28):

| Gate | Scope | State | Evidence |
| :--- | :--- | :--- | :--- |
| Gate 1 (M19R) | Truthful, immutable evidence; receipts derived from observed gate output | Merged | `aien-spark/omega#30` (`04d80f5`), `aien-spark/omega#33` (merge `49480cd`, 2026-09-27); receipt `evidence/M19R/c4d87451bbde1d8f09442191f735e893fd47916e72a6330c96df84e9e6028404.json`, recorded from clean omega `e5159fa` + physics `29bf6ea` |
| Gate 2 (M19R-RUNTIME) | GPU memory lifecycle, exactly-once completion, long-run soak | Merged | `aien-spark/omega#31` (`1feb832`), `aien-spark/omega#33` (same receipt as Gate 1: PASS=229, 100,000-cycle soak passed, RM balance/allocations/mappings/registries back to zero) |
| Gates 3-4 (FORGE-0, FORGE-HWID) | FORGE realize / AEGIS verify seam; observed hardware identity | PASS | aien-spark/physics#13 merged 5969159; Gates 3 and 4 pass (11/11, 10/10) |

| Gate 5 (OMEGA-NUMERIC-0) | FP32 Blackwell machine vocabulary | Merged | `aien-spark/omega#110` / `8024e9a`; receipt `evidence/OMEGA-NUMERIC-0/dc4e6012e52b2108781e77d2427a1c49b6b71f307ba918f4a62174c5d35aa746.json` (PASS=36) |
| Gate 14 (Combined Foundation) | Combined Foundation Admission (evidence, runtime, Forge, FP32) | Merged / PASS | `aien-spark/omega#111` (`5517d22`); receipt `evidence/GATE14-FOUNDATION/50dd611bfd28e8320443810b35f7425df5eb112777662e5840c227154271f872.json`, binding clean Omega `8024e9a` + Physics `e95e3ed` (8/8 criteria satisfied). M19 resident foundation requalification is CLOSED. |

### ADR 0016 (ARCH-0016) resident reaction stages R0-R16

These are the implementation stages of ADR 0016, not roadmap milestones; they carry no M-number and do not change the table in §2. Each row cites the `aien-spark/omega` receipt on `main` (`evidence/<stage>/<digest>.json`) and the verdict it records.

| Stage | Verdict recorded in receipt | Where it ran | Merged via (`aien-spark/omega`) |
| :--- | :--- | :--- | :--- |
| R0 | Satisfied by ADR 0016 itself (`aien-architecture#42`, `4790423`) | — | — |
| R1 `R1_CANONICAL_WORLD` | PASS | host CPU, not silicon | #39, #40 (`evidence/R1/`) |
| R2 `R2_CROSS_ENGINE_ABI` | PASS | host CPU, not silicon | #39, #40 (`evidence/R2/`) |
| R3 `R3_REACTION_CORE` | PASS | host reference | #35 (`e2667c2`, `evidence/R3/ef3e5565...json`) |
| R4 `R4_CAUSAL_TRACE` | PASS | host reference | #35 (same R3 receipt; no separate `evidence/R4/`) |
| R5 `R5_RESOURCE_ARBITRATION` | PASS | host reference, not silicon | #36-#38 (`evidence/R5/`) |
| R6 `R6_REACTION_STABILITY` | PASS | host reference, not silicon | #36-#38 (`evidence/R6/`) |
| R7 `R7_NATIVE_AUTHORITY` | PASS | host, against the native C authority (Linux oracle retained) | #41, #43 (`evidence/R7/3165ff4c...json`) |
| R8 `R8_CONSTITUTIONAL_AEGIS` | PASS | host | #48 (`fe4924a`, `evidence/R8/a666db9f...json`) |
| R9 `R9_GENERATION_BARRIER` | PASS | host | #42 (`00be7ae`, `evidence/R9/642cf1bf...json`) |
| R10 `R10_CONTINUOUS_OMEGA` | PASS | DGX Spark CPU | #46 (`0a787ee`, `evidence/R10/1ea7acfe...json`) |
| R11 `R11_CONTINUOUS_COGNITION` | PASS | DGX Spark CPU | #47 (`628daf5`, `evidence/R11/6aa6b3b3...json`) |
| R12 resident GPU seat | PASS | GB10 silicon | #44 (`05b0692`), hardening #45 (`4331bf3`) (`evidence/R12/`) |
| R13 faculties as one causal system | PASS (causal verification PASS, AIEN goal MET) | GB10 silicon | #49 (`fcb5793`, `evidence/R13/48d5a36c...json`) |
| R14 living recovery | PASS | GB10 silicon | #50 (`f70ae10`, `evidence/R14/0c091687...json`) |
| R15 quantitative performance | HISTORICAL PASS (16/16 at omega `3e9e53b`); requal FAIL 14/16 (G1, G15) at `3108fc2`; NOT requalified on CAND-0 or CAND-1 (CAND-1: R15 parity host and silicon PASS; the performance receipt needs a quiet machine, NOT_RUN) | DGX Spark (per receipt) | #67 (`bba3bd3`, `evidence/R15/065c6884...json`, outcome PASS, 16/16 gates); requal `evidence/REQUAL-3108fc2/` |
| R16 orchestrator retirement | HISTORICAL PASS at `850fc54`; requal FAIL at `3108fc2`; NOT requalified on CAND-0 or CAND-1 (CAND-1 harness: G1-G5 PASS, G6 not implemented, G7 waits on the R15 performance receipt, G8 outside the script; `qualification/candidates/CAND-1.gates.md`) | DGX Spark | `aien-spark/omega#112` merged (`3dd5eaa`). Receipt `22d7a79a` is INVALID as a current claim (its script was later found defective); requal `evidence/REQUAL-3108fc2/` recorded R16 FAIL; the CAND-0 loop inventory reconciled to 502 sites, 0 unclassified, 0 stale (omega PR #279, inventory only). Recorded originally: all gates G1-G8 PASS on clean candidate `850fc545770554c8db45e97acf20224663878685`. Canonical receipt `evidence/R16/22d7a79a985514ac38139d39c71c9638d9b6b0a6e05425b6810bdb4833d1ea64.json` (`AIEN_RX_R16_ORCHESTRATOR_RETIRED_V1`). 281/281 sites classified (0 unclassified). Full R1-R15 candidate ladder passed on GB10 silicon. Runtime freeze on `omega/src/runtime/` lifted. Exception recorded 2026-10-01: `#112` merged with its `evidence-immutable` check FAILED (run `36799862685`); `evidence/R16/inventory.json` was edited in place by `1edb56b` and `6831117`, which the PR did not record. |

Status updated 2026-09-30 upon candidate-bound silicon qualification receipt and PR #112 merge. Correction 2026-10-05 (source `reports/L2-EVID.md`): the R15 and R16 rows above are historical PASS at their own candidates; requalification at omega `3108fc2` recorded R15 FAIL 14/16 (G1, G15) and R16 FAIL (omega `evidence/REQUAL-3108fc2/`); the R16 receipt `22d7a79a` at `850fc54` is INVALID as a current claim; none of R1 to R16 is requalified on CAND-0 (omega `e5593ae`) and the ladder rerun is in progress. ADR 0016 migration is therefore NOT claimed COMPLETE on the current candidate.

Scope note (2026-10-01, Lane 33): every candidate-bound R13 to R16 receipt above binds a commit that predates omega `#126` (`4f8485b`), which added J-Space, Cortex, the Capability Graph, the Skill Router and composition (and later Fabric, `#132`/`#135`) to the R13 living build. R1 to R16 are qualified at their own candidate commits only. The living build on current main has one R13 run, `evidence/COMPOSITION-2/4957ef16...json`, SILICON_PASS_UNBOUND (`candidate_bound: false`), and R16-G3 has not been re-run on it: the current living build is IMPLEMENTED / NOT QUALIFIED until re-qualified. The rows above are not changed.

### ADR 0020 (ARCH-0020) belief / estimation stages EST-0-EST-10

These are the implementation stages of ADR 0020, not roadmap milestones; they carry no M-number and do not change the table in §2. EST-4 and later wait for R16 closure.

Status 2026-10-01 (R16 wording corrected 2026-10-05: R16 is a historical PASS, not requalified on CAND-0, see the R16 row): R16 was closed (`aien-spark/omega#112` `3dd5eaa`), so EST-4 and later no longer wait on R16; they wait on a passing EST-3 calibration. Three frozen calibration attempts are recorded as FAIL and kept: v1 `aien-spark/omega#105` `6d1ff1d`, v2 `#118` `8a56ace`, v3 `#129` `d78fd11` (Phase A FAIL, sealed run NOT_RUN, omega `docs/estimation/receipts/est3c-v3/RESULT.md`). v4: INCONCLUSIVE (omega#153 merged 2026-10-01); v5 in progress (omega#170, open). All three attempts VOID, no verdict.

| Stage | Exit token | Status |
| :--- | :--- | :--- |
| EST-0 semantic contract | `ESTIMATION_SEMANTIC_CONTRACT` | IN PROGRESS (standalone module; code merged `aien-spark/omega#105` `6d1ff1d`) |
| EST-1 linear Kalman reference | `LINEAR_KALMAN_REFERENCE` | IN PROGRESS (standalone module; code merged `aien-spark/omega#105` `6d1ff1d`) |
| EST-2 real signal | `ESTIMATION_REAL_SIGNAL` | IN PROGRESS (signal tools merged `aien-spark/omega#105` `6d1ff1d`; exit not claimed) |
| EST-3 calibration | `ESTIMATION_CALIBRATION` | FAIL recorded (v1 `omega#105`, v2 `omega#118`, v3 `omega#129`); v4: INCONCLUSIVE (omega#153 merged 2026-10-01); v5 in progress (omega#170, open) |
| EST-4 World belief state | `WORLD_BELIEF_STATE` | PLANNED (blocked on a passing EST-3) |
| EST-5 Omega cost model | `OMEGA_ESTIMATION_INTEGRATION` | PLANNED (blocked on a passing EST-3) |
| EST-6 TURING evidence | `TURING_ESTIMATION_EVIDENCE` | PLANNED |
| EST-7 J-Space | `JSPACE_BELIEF_INTEGRATION` | PLANNED |
| EST-8 Cortex | `CORTEX_PREDICTIVE_MEMORY` | PLANNED |
| EST-9 innovation curiosity signal | `INNOVATION_CURIOSITY_SIGNAL` | PLANNED |
| EST-10 active information gain | `ACTIVE_INFORMATION_GAIN` | PLANNED |

### M20: `OMEGA_TENSOR`
- Status 2026-10-01: table status stays PLANNED; no exit gate is met. A semantic layer + CPU realization is OPEN as `aien-spark/omega#136` (not qualified). Its prerequisite E1 numerical closure is not closed: scalar contract CPU tier `aien-spark/omega#124` `d3194f6` and reductions `#134` `c54d492` merged; transcendental sequences `#127` (`7a5a13c`, CPU only) and standalone GB10 DIV/SQRT `#141` (`6b14354`) are merged (corrected 2026-10-01, Lane 33; they were already merged or merging when this note was written), as are GB10 main-path WP-C `#147` (`2d8cd68`) and DIV/SQRT `#152` (`07004a8`). E1 is still PARTIAL, 2 of 6 exit requirements met; `#136` remains an open draft (see `CURRENT_EXECUTION_PLAN.md` §2 Lane 33 addendum).
- Status 2026-10-02: the E1 prerequisite is CLOSED on the GB10 chip campaign at omega `fb36109` (merged `40d1ea37`, `aien-spark/omega#225`, Physics `e95e3ed`): consolidated receipt omega `evidence/E1-CLOSURE/e7851c69d34ac777a9436af16d0bdd5d69264c8528c62d562b600f5d89153061.json`, six of six E1 bullets met, exclusions recorded in omega `docs/numeric/E1_GAP_TABLE.md` (natural-base EXP/LOG not on GB10). M20 `OMEGA_TENSOR` itself is unchanged: table status PLANNED, `#136` an open draft, no exit gate met.

### M22 — `OMEGA_OPTIMIZER`
Omega-native semantics for SGD, Adam, and AdamW, with verified CPU reference realizations and optional accelerator-fused realizations.
- Status 2026-10-01: table status stays PLANNED; no exit gate is met. Discrepancy recorded: substrate work has started although the vocabulary row reads "Not started". `aien-spark/omega#140` (`54826a3`) merged a shadow-state optimizer substrate with one atomic generation switch, E5 two-tier provenance and a float32 SGD path; receipt omega `evidence/M22/receipts/eaa0cdeae9f348b19b80377baaeb5e5dea6a6577e9385e7a2a3c15caab24c5c8.json` records substrate tests PASS and "M22 NOT QUALIFIED: optimizer substrate + SGD path only; no tensor/autodiff integration (waits M20/M21)". Adam/AdamW are not implemented.
- Scope note 2026-10-03: M22 means training optimizers that update model parameters (SGD, Adam, AdamW). Adaptive pricing of soft machine resource budgets (DUAL, ADR 0031, `CURRENT_EXECUTION_PLAN.md` Lane 8) is a separate workstream with its own gates; it is not part of M22, and no M22 status changes because of it.

### M23: `OMEGA_SEARCH_GUIDE_TRAINING`
- Status 2026-10-01: table status stays PLANNED; no exit gate is met (training NOT_RUN, waits on M22). Discrepancy recorded: the corpus prerequisite exists. G1 search-trace corpus capture PASS (`aien-spark/omega#122` `ce7821d`; receipt omega `evidence/M23/receipts/m23-corpus-ee4982119af7244086187c9b643cb9c1823c6b0a2b796f861d2d4077edb5256d.json`); G3 sealed-holdout commitment format PASS, format only, nothing sealed (`#122`), commitment owner signature with TEST keys (`#130` `7fb59d3`). Sealing and real owner signing are BLOCKED_OPERATOR.

### DIRAC-0 (ARCH-0023, PROPOSED; downstream consumer, not a milestone)
- Status 2026-10-01: no table row. DIRAC-0 (`docs/plans/dirac/DIRAC-0-SPEC.md`) consumes OSC-2, E1, M20 `OMEGA_TENSOR`, ESTIMATION and TURING and creates no new tensor, measurement, GPU-runtime or evidence system. `DIRAC_PREP_FROZEN` is proposed, not passed; no roadmap milestone changes.

### M40 — `AIEN_SUCCESSION`
Closed-loop self-improvement: AIEN-N designs AIEN-N+1 under Physics canary control.

---

**Addendum 2026-10-01 (language course correction):** [ADR 0024](../docs/adr/0024-rust-scaffolding-omega-destination.md) supersedes the Rust-to-C migration plan. Rust is scaffolding, Omega is the destination, and C stays only where hardware-justified. No milestone, gate or order in this roadmap changes.

<!-- HISTORICAL-PROVENANCE:BEGIN -->
## 4. Historical Provenance: Superseded Roadmap Generations

> **HISTORICAL — NOT NORMATIVE.** Retained only to explain older references. Do not cite these numbers.

- **28-milestone workstream roadmap (M0-M27, workstreams A-F):** ended at M27 `SOVEREIGN_MACHINE_CLOSURE`; its identifiers (e.g. `ATLAS_BAREMETAL_BOOT`, `PHYSICS_CORE_MEMBRANE`, `SENTINEL_GATE_1..3`) are retired.
- **31-milestone program-learning roadmap (M0-M30):** placed `AIEN_HUMAN_INTERFACE` at M27, `AIEN_RESIDENT` at M28, `OMEGA_CONTINUAL_LIBRARY_LEARNING` at M29, and `AIEN_SUCCESSION` at M30. Superseded by the 41-milestone roadmap above when Physics Zero (DOCTRINE-006) was ratified.
- **Alpha lineage:** `atlas.bin` was designated Alpha (`alpha.bin`) during early bootstrap drafting; the Alpha evidence bundle names (`alpha.manifest`, `alpha.sha256`, `alpha.decode`, `alpha.memory-map`, `alpha.control-flow`, `alpha.audit`) are retired in favour of `atlas.*`.
<!-- HISTORICAL-PROVENANCE:END -->
