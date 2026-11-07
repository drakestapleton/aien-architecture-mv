# Architecture Decision Records

Resolved architectural decisions are recorded here so implementation agents do not repeatedly reopen settled boundaries.

## Naming ADRs across repositories

`aien-architecture` and `aien-dev/aienux` number their ADRs independently, so the same number (for example 0012 or 0016) names two different decisions. In prose (docs, plans, issues, PRs, commit messages), cite an ADR with its repository prefix:

- `ARCH-00nn`: an ADR in this repository (`aien-architecture/docs/adr/`), e.g. ARCH-0016 is the resident reaction architecture.
- `OS-00nn`: an ADR in `aien-dev/aienux` (`docs/adr/`), e.g. OS-0012 is self-construction, capability growth and generations.

A bare "ADR 00nn" is acceptable only inside the repository that owns it. Files are not renamed: the prefix is a citation convention, and existing file names and historical references stay as they are.

Current ADRs:

- [0001 - Canonical composition root](0001-canonical-composition-root.md)
- [0002 - Hardware-neutral Machine identities](0002-hardware-neutral-machines.md)
- [0003 - Tools and Skills are distinct](0003-tools-vs-skills.md)
- [0004 - MCP is a compatibility layer](0004-mcp-compatibility-layer.md)
- [0005 - Irreversible effects require a broker](0005-effect-broker.md)
- [0006 - Production secrets are vault-only](0006-vault-only.md)
- [0007 - J-Space cannot externalize speculative effects](0007-jspace-effect-boundary.md)
- [0008 - Relational paths are first-class evidence objects](0008-relational-paths.md)
- [0009 - Names state implemented contracts](0009-names-state-implemented-contracts.md)
- [0010 - Canary observations are measurements](0010-canary-observations-are-measurements.md)
- [0011 - An inference context is model state](0011-inference-context-is-model-state.md)
- [0012 - One shell dispatch, then a landing split](0012-shell-dispatch-then-landing.md)
- [0013 - Machine Physics Lowering and AEGIS Invariant Verification Chain](0013-machine-physics-lowering-and-aegis-invariant-checker.md) - naming superseded by ADR 0014
- [0014 - Rename Machine Physics to FORGE](0014-rename-machine-physics-to-forge.md)
- [0015 - Resident Semantic Store Boundary, Object Identity, and Reconstruction Contract](0015-resident-semantic-store.md)
- [0016 - AIEN, Omega, and AEGIS are faculties of one resident reaction system](0016-resident-reaction-architecture.md) - Amendment 1, 2026-10-02: FORGE is a realization policy, not a commit step
- [0017 - ARGUS is the defensive plane; it observes, detects, and proposes, but never authorizes](0017-argus-defensive-plane.md) - Accepted by operator Drake Stapleton, 2026-09-29
- [0018 - Substrate-neutral physical realization](0018-substrate-neutral-physical-realization.md) - Accepted by operator Drake Stapleton, 2026-09-29
- [0019 - Mixed-algebra realization](0019-mixed-algebra-realization.md) - Accepted 2026-09-29
- [0020 - Belief / estimation layer](0020-belief-estimation-layer.md) - Accepted by operator Drake Stapleton, 2026-09-30
- [0021 - Four operating decisions of 2026-09-30: Physics pin, SSD block layout, admission receipts, R16 status](0021-four-operating-decisions-2026-09-30.md) - Recorded 2026-09-30 from the orchestrator brief
- [0022 - The canonical Cortex owner is omega `rx_cortex`](0022-canonical-cortex-owner.md) - Accepted 2026-09-30 (orchestrator engineering call under the operator's standing rule)
- [0023 - DIRAC-0 Program (Integration Workstream)](0023-dirac-0-program.md) - PROPOSED 2026-10-01
- [0024 - Rust is scaffolding, Omega is destination, C where hardware-justified](0024-rust-scaffolding-omega-destination.md) - Accepted by operator Drake Stapleton, 2026-10-01 (supersedes the Rust-to-C migration plan)
- [0025 - One execution transcript, one causal id chain, one resource-contract vocabulary](0025-execution-transcript-causal-id-resource-contract.md) - PROPOSED 2026-10-01
- [0026 - Sealed Discovery Examinations](0026-sealed-discovery-examinations.md) - PROPOSED 2026-10-01
- [0027 - Formal verification uses Lean as a temporary oracle; Omega owns the invariants](0027-formal-oracle-lean-bootstrap.md) - Accepted by operator Drake Stapleton, 2026-10-01 (via his Formal Verification Bootstrap Plan)
- [0028 - AIEN-TEST: manifest v1, EvidenceReceiptV1, verdict set, resource pools, incremental digests, Omega-native successor](0028-aien-test-runner-and-evidence-contract.md) - Accepted by operator Drake Stapleton, 2026-10-02 (via his approved `aien-test` spec)
- [0029 - Verified Crumbs: Omega's verified library is the only dependency resolver](0029-verified-crumbs-single-dependency-resolver.md) - Accepted by operator Drake Stapleton, 2026-10-02 (via his approved Verified Crumb plan); amends ARCH-0028 Decision 4 (receipt contract)
- [0030 - Switchboard: one typed router over our own AI accounts](0030-switchboard-ai-account-router.md) - PROPOSED 2026-10-03
- [0031 - DUAL: constraint pricing for soft resource budgets; hard gates are never priced](0031-dual-constraint-pricing.md) - Accepted by operator Drake Stapleton, 2026-10-03 (via his "DUAL / Constraint Pricing" brief)
- [0032 - Inertial Alignment (ANS): frozen reference, drift filter, three sensor classes, autonomy tiers, promotion gate; advisory only](0032-inertial-alignment.md) - Accepted by operator Drake Stapleton, 2026-10-03 (via his "fully implement this feature /goal Inertial Alignment" instruction on the pasted brief)
- [0033 - AIEN Verification: gate manifests, exactness classes, Spark verifier, signed verification bundles, GitHub thin gate](0033-aien-verification-pipeline.md) - Written 2026-10-04, amended 2026-10-11; by its own rule it became ACCEPTED when its PR (#126) merged. Phase 3 (the Spark is the only test judge) in effect since 2026-10-16; hosted test workflows removed 2026-10-18 (#270)
- [0034 - Physical-Form Realization IR: substrate-neutral realization form below Omega meaning and beside substrate lowering; LINEAR_OPERATOR first cut, ENERGY_FUNCTIONAL specified only](0034-physical-form-realization-ir.md) - Accepted by the orchestrator under operator delegation of 2026-10-04 (Drake: "make the calls yourself"); operator may revoke; extends ADR 0018 / 0019
- [0035 - Persistent Cognitive Entity Boundary (Aien): AIEN is the organism, Aien the durable subject it sustains; one continuity object kind (aienux docs/adr/0018-allen-subject-state-object.md), three bindings in omega, six host gates incl. negative control](0035-persistent-cognitive-entity-boundary-aien.md) ([aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md)) - ACCEPTED 2026-10-06 by the operator; creed and ARCHITECTURE.md edits applied; aienos#259, omega#276; native genesis and QEMU cold restart TESTED (QEMU) in aienos#260, hardware NOT_RUN
- [0036 - Release v1 memory owner (lane L3): aien-allen-memory under an engaged Aien identity (rename to aien-subject-memory planned); remember and recall refuse when not engaged; every declared E2E run engages a fixture subject](0036-release-v1-memory-owner.md) - ACCEPTED 2026-10-10 (engineering decision under Drake directive; aien-architecture#197, aien-sovereign-core#386)
- [0037 - Who signs native slot images: Owner Root directly, or a Release Signer it delegates to](0037-native-image-slot-signing-roles.md) - ACCEPTED 2026-10-12: Option A for native v1, Option B follow-on (addendum to 0024 Q3; aienos#333, aien-architecture#190)
- [0038 - Names: Aienux is the kernel, AienOS is the operating system, the old names are retired](0038-names-aienux-kernel-aienos-system.md) - ACCEPTED 2026-10-20 (Drake; ledger L180); Superseded in part by ADR 0045 (line 23, and AienOS as the name of the whole system)
- [0039 - The typed-construction interface is Omega's primary agent programming interface: inspect / legal_actions / apply / obligations / realize / verify / explain_refusal; INVALID / INCOMPLETE / VALID-UNPROVEN / UNKNOWN](0039-typed-construction-agent-interface.md) - ACCEPTED 2026-10-26 (Main, delegated by Drake)
- [0040 - Five identities; "same meaning, same identity" holds only under a named normalization system that fails toward CHANGED](0040-identity-layers-normalization.md) - ACCEPTED 2026-10-26 (Main, delegated by Drake); narrows the reading of 0015, 0018, 0019
- [0041 - Aienux is written in Omega; the legacy C kernel is sunset](0041-aienux-written-in-omega-c-kernel-sunset.md) - ACCEPTED 2026-10-24 (Drake): Omega is the only kernel language; C kernel frozen to bug fixes, retired at parity; transition plan PROPOSED (L802). Rebased onto main after ARCH-0039 and ARCH-0040 landed (PR #322 was CONFLICTING).
- [0042 - Omega owns computation, CUDApp owns GPU execution, Omega Bridge owns compatibility](0042-omega-cudapp-bridge-ownership.md) - ACCEPTED 2026-10-30 (Drake; merged as #342; proposed 2026-10-26). (Drake's forwarded omega-bridge assessment, 2026-10-27); duplication issues CUDApp#106-108, CUDApp#10, omega-mv#870-871
- [0043 - GPU stack: portable Omega top, thin per-target backend behind one 30-call ABI; one kernel source (Omegese → IR → checker2); unified memory; AMD second, Vulkan fallback; ggml/vLLM/ORT attachments; human review rule](0043-gpu-stack-portable-top-thin-backend.md) - ACCEPTED 2026-10-30 (Drake; lane SplitDesign; design only, code gated on P0 + C2–C5 QUALIFIED)
- [0044 - One cubin writer per NVIDIA target family, owned by CUDApp](0044-one-cubin-writer-per-nvidia-target-family.md) - ACCEPTED 2026-10-30 (Drake); one `.om` writer per NVIDIA target family under CUDApp `backend/<target>/` (the NVIDIA directory is created when the work moves); `omega_cubin.c` frozen; CUDApp#108, CUDApp#170, CUDApp#190, omega-mv#864
- [0045 - Aienix retired; sovereign-intelligence is the center of AIEN](0045-aienix-retired-sovereign-intelligence-center.md) - Accepted (Drake, 2026-10-30; relayed by Aien)
- [0046 - Omega NG: one seeded compiler for CPU and GPU (Omega and CUDA++ unified)](0046-omega-ng-one-seeded-compiler-cpu-gpu.md) - Accepted (Drake directive 2026-11-07, relayed by Manager(Aien)); ΩIR single semantic IR in omega-mv `seed/ng/**`; NG consumes CUDApp's seeded encoder, allocator and cubin writer at a pin; supersedes nothing, no ownership moves
