# ADR 0035: Persistent Cognitive Entity Boundary (Aien)

**Status:** ACCEPTED (2026-10-06, by the operator, Drake Stapleton: "Yes I accept Allen", accepted as written including the creed line). Proposed 2026-10-04. The creed line and `doctrine/ARCHITECTURE.md` §1.2 / §1.3 / §2.8 were updated on acceptance (see §3 item 8 and §5). The aienos Blueprint is not changed by this record (no Blueprint sentence is named in §3 or §5); [aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md) keeps its own status until its own format-freeze approval. What is already true on branches is marked IMPLEMENTED / TESTED below; nothing in this ADR is QUALIFIED on hardware.
**Author:** Claude (Fable 5.1) for Drake Stapleton. Investigation: `~/handoffs/2026-10-04-allen-architecture-investigation.md`; drift re-audit before implementation: `~/handoffs/2026-10-04-allen-phase-a-delta.md`.
**Supersedes:** nothing. **Amends (on acceptance, applied 2026-10-06):** `doctrine/ARCHITECTURE.md` §1.2 gloss of AIEN PROPOSES ("initiates intent" moves to Aien), §1.3 creed, §2.8 ownership table (new rows). **Already changed in companion PRs (no acceptance needed; they state facts about code):** `doctrine/AIEN.md` §10 model-generation naming (this PR, second commit); aienos `docs/ARCHITECTURE.md` §10 and `CONTEXT.md` "AIEN Agent" (aien-dev/aienux#259); omega `spec/allen.md` (aien-spark/omega#276).
**Related:** ARCH-0007 (J-Space effect boundary), ARCH-0011 (inference context is model state), ARCH-0015 (resident semantic store), ARCH-0016 (resident reaction system; readiness, not turn order), ARCH-0020 (belief / estimation), ARCH-0022 (Cortex owner), ARCH-0024 (Rust scaffolding, Omega destination), ARCH-0028 (aien-test), omega R16 (orchestrator retirement); aienos ADR 0006, 0007, 0015, 0016, 0017, **[aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md) (Aien subject state object, PROPOSED)**.
**Evidence base:** GitHub `main` on 2026-10-04: aien-architecture 6c95697, aienos fbbfc9c, omega e5593ae, aien-sovereign-core 6c28524, aegis-runtime f4e8709, aien-protocols 3a4cdbe, interplane 59bb72b. Branches: aienos `feat/allen-subject-state` (cd4b089, PR #259), omega `feat/allen-v0` (7151e45, PR #276). Code beats plans.
**Name:** Aien is a proper name, not an acronym; no five words are manufactured for it. When this record was accepted the subject was named ALLEN, echoing Alan Turing (spelled Alan), whose measurement line the project already carries, and the project creator's first best friend; it was not changed to ALAN. Allen has now evolved into the final Aien (2026-10-26).

Citation note: in this repository "ADR 0035" and ARCH-0035 name the same decision.

---

## In plain words

Until now the word AIEN meant four things: the whole living system, the thinking part of that system, the one individual that is supposed to survive reboots and model swaps, and (by accident, in one doctrine section) a particular version of the model. The individual had a 32-byte id in AIENOS and nothing else: no record of what it currently wants, what it holds as known, or which memory journal is its own. A restart lost the standing goal even though the memory journal had recorded it. This decision gives that individual a name, Aien, and one small durable state object. Aien is not a new layer, not a scheduler, not a memory, not a planner, not a chat. It is the subject that the rest of AIEN works for.

## 1. Context

1. `doctrine/ARCHITECTURE.md` §1.1 and §2.2 define AIEN as the cognitive layer. ADR 0016 defines AIEN as "a persistent resident computational organism" with AIEN, Omega and AEGIS as its faculties. aienos `docs/ARCHITECTURE.md` §10 said "The persistent thing is AIEN itself." `doctrine/AIEN.md` §10.2 named model generations "AIEN-N", "AIEN-N+1", while §12.1 says "AIEN is Not a Weight Matrix" and aienos `CONTEXT.md` says a model is a replaceable component with no identity.
2. Code on `main` (re-audited 2026-10-04 before implementation; delta note): aienos holds the AgentRoot (continuity kind 16), ContinuityManifest (kind 17) and the branch table (kind 18, `cc_state`) over Store v1 (aienos ADR 0016, PROPOSED), resolved by `native/kernel/svc/continuity_resolve.c`; the manifest has no free slot; the resolver ignores untracked kinds. omega `src/runtime/rx_aien.h` implements AIEN as a resident faculty (observe, predict, explain, assess, plan) whose goal object is "written from outside" and labelled "(external, human)"; the only path for that write is `rx_world_publish_external` under the World's external-subject capability; a World holds it in memory only. omega `rx_cortex` is the canonical Cortex (ARCH-0022); its journal header reserves a word for a future machine identity and has no identity, self or goal record kind. The model's identity in code is a digest in the boot handoff (`native/boot/handoff.h: model_sha256`); there is no ModelId type.
3. INTERPLANE's runtime-side counterparty is a `RuntimeAuthority` (decide / execute / catalog); its session is an opaque handle. It has no concept of agent identity or continuity.
4. `doctrine/ARCHITECTURE.md` §2.8 has no rows for identity, standing intent or the identity-to-memory binding.

## 2. The collision this resolves

| meaning of "AIEN" | kept? | name |
|---|---|---|
| 1. the organism (World, faculties, Cortex, Store) | kept | AIEN |
| 2. the cognitive faculty that proposes | kept | AIEN ("AIEN PROPOSES") |
| 3. the one durable subject that survives restarts and model swaps | renamed | **Aien** |
| 4. a model generation ("AIEN-N") | corrected | model generation N (`doctrine/AIEN.md` §10) |

## 3. Decision (accepted 2026-10-06)

```text
AIEN IS THE ORGANISM. Aien IS THE SUBJECT IT SUSTAINS.
Aien IS DURABLE STATE BOUND TO ONE LOGICALAGENTID. Aien IS NOT A LOOP.
Aien HOLDS STANDING INTENT, HELD KNOWLEDGE REFERENCES AND THE
IDENTITY-TO-MEMORY BINDING. EVERYTHING ELSE KEEPS ITS PRESENT OWNER.
```

1. **Definition.** Aien is the persistent cognitive subject sustained by the AIEN organism: one chain of durable, content-addressed state objects bound to one AIENOS `LogicalAgentId` and its AgentRoot, holding what the subject currently intends (standing intents), what it holds as known (references to Cortex promotion records, by digest), and the binding that names its memory (the Cortex journal lineage).
2. **Format (IMPLEMENTED, [aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md)).** AIENOS continuity object **kind 24, SubjectState**, format_version 0, 16-byte header as every continuity object, fixed little-endian layout, at most 9416 bytes. One ACTIVE intent per slot; supersession is named by exactly one successor; intent ids derive from content; the chain is gap-free and fork-free from sequence 1; a foreign root or agent, a fork, a gap, a broken link or an unknown claim version is CORRUPT; a Store with a root and no subject object is ABSENT and the kernel never mints one. The object carries **no capability, weight, model, machine, process or queue field**: model independence is structural.
3. **Identity (IMPLEMENTED).** Aien is the agent the AgentRoot already names. There is no `AienId`. The subject object carries the `LogicalAgentId` and the AgentRoot id and is refused by the resolver if either is foreign. On the omega side the World's external subject number is recorded against that agent (the binding record, `src/allen/allen_bind.h: AllenBinding` (planned rename: `src/aien/aien_bind.h: AienBinding`)).
4. **Memory (IMPLEMENTED).** The lineage reference is the digest of the Cortex journal's record 1 (ARCH-0022). A subject acts only with the journal whose lineage it names; anything else is refused before any publication (fail closed). The journal header's reserved identity word is left alone; nothing in Cortex is redesigned.
5. **Standing intent (IMPLEMENTED, one kind).** v0 defines `GOAL_LATENCY` (regime, target ns), the one goal shape `rx_aien` reads today. Aien publishes each ACTIVE intent as the goal mutation through `rx_world_publish_external`; the EXTERNAL crumb carries the intent id's first 64 bits. The World's dependency machinery wakes `aien.assess`. Other kinds are FUTURE.
6. **AIEN keeps PROPOSES.** Proposing, hypothesis formation, prediction, explanation, planning, search, synthesis, cost modelling and the Turing measurement remain faculty work under their present owners. The one gloss word that moves is "initiates intent" (ARCHITECTURE §1.2), which becomes Aien's on acceptance.
7. **Position.** Aien is inside the AIEN organism, not above it. The layer order in ARCHITECTURE §1.1 does not change.
8. **Creed (applied on acceptance, 2026-10-06).** `ATLAS AWAKENS. ALLEN INTENDS. AIEN PROPOSES. OMEGA DEFINES. FORGE REALIZES. AEGIS VERIFIES. HARDWARE ACTS. EVIDENCE TEACHES.` The line reads correctly against the implemented boundary: Aien's object says what is intended; AIEN's faculty proposes what to do about it. It is applied on acceptance.
9. **Model naming (applied in this PR).** `doctrine/AIEN.md` §10 names model generations "Model N / N+1 / N-1" serving Aien; the succession triad and the non-self-promotion law are unchanged.

## 4. Alternatives considered and rejected

- **A: no Aien.** Rejected by the negative control (§8): a standing intent does not survive a restart through Cortex alone; something must own it, and nothing did.
- **B: Aien as a plain sub-module of AIEN.** True structurally (it is three bindings and one object kind), but it hides that Aien resolves a doctrine naming defect; this ADR records both.
- **C: Aien above AIEN with AIEN as machinery.** Rejected: contradicts ADR 0016's organism sentence and ARCHITECTURE §1.1 / §2.2.
- **Aien as the "AIEN Agent" of aienos (planner / router / operator UI).** Rejected: a service shape; it would recreate the orchestrator R16 retired.
- **Aien as memory or planning.** Rejected: Cortex (ARCH-0022) and J-Space / `rx_plan` own those.
- **Aien as the payload of continuity kind 18.** Rejected at the drift re-audit: kind 18 is the branch table. (The earlier draft said kind 18; that was wrong.)
- **A slot in the ContinuityManifest.** Rejected: no free slot; frozen format; every Store would need a version bump.
- **A new `AienId`.** Rejected: a second identity that must be kept in step with the AgentRoot and can drift from it.
- **Keeping the standing goal in Cortex.** Rejected: Cortex is an append-only record of what happened; a standing intent is a claim about the present that the kernel resolves.

## 5. Ownership changes

| concept | from | to |
|---|---|---|
| "initiates intent" | AIEN (gloss, §1.2) | Aien (accepted 2026-10-06) |
| standing goal source in the living runtime | unowned ("external, human") | Aien object, published through the existing external path |
| held-knowledge set (which promotions are the subject's own) | unnamed | Aien (by digest; records stay in Cortex) |
| identity <-> Cortex journal <-> World subject binding | absent | Aien (binding record); the mechanisms stay with AIENOS and omega |
| everything else in ARCHITECTURE §2.8 | unchanged | unchanged |

What did **not** change: AIEN cognition (`rx_aien` reads the same goal object, unmodified), R16 (no loop, no faculty call), Omega, AEGIS, Cortex ownership (ARCH-0022; one lineage reference read, nothing written by Aien), J-Space ownership, INTERPLANE authority (`INTERPLANE IMPACT: NONE`), the AIENOS capability authority (the only mint).

## 6. Invariants

- I1 Aien's subject id is invariant under model replacement (TESTED: G4).
- I2 Aien's subject id is invariant across process restart (TESTED: G2 in omega; two processes over one sealed Store image in aienos).
- I3 Aien contains no capability, weight, KV state, machine id, process or queue reference (structural; the format has no such field).
- I4 One subject chain per AgentRoot in v0. A fork is CORRUPT and stops in the resolver; multi-subject Stores are FUTURE and the format does not preclude them (every object names its root and agent).
- I5 Aien's held set references only Cortex promotion records, by digest; never candidates or raw claims.
- I6 Aien's objects change only by a committed successor that continues the resolved chain (stale successor and second genesis refused).
- I7 Aien has no thread, no poll, no timer and no call into any faculty. Faculties react to Aien's publications by readiness (TESTED: G5 symbol scan; R16 loop inventory unchanged).
- I8 Aien is never created implicitly; the kernel reports ABSENT and never mints a subject.

## 7. R16 compatibility (binding gate)

Aien is state. The only thing it does at run time is publish typed state through `rx_world_publish_external`, which is the path the human already used. No semantic master loop returns: `allen_bind.o` (planned rename: `aien_bind.o`) carries no thread, wait, clock, signal, reaction-registration or mint symbol; the host tool carries none of thread, timer, signal, reaction or fork; the cross-repo loop inventory on the omega branch equals `main` (256 omega sites, 0 new). Preserving R16 was an implementation gate (G5), not a preference.

## 8. Negative control (the falsifier)

Before Aien could pass, the test had to show that the intent does **not** already survive a restart without it. omega `tests/allen/run.sh` (planned rename: `tests/aien/run.sh`) G6: a fresh Cortex journal; one publication through Aien (the journal then holds 15 records: the EXTERNAL crumb, the AIEN activations, the commits); the rig started again **without** Aien holds **0 goals**; the rig started again **with** Aien holds the goal (regime 7, target 1000 ns). Had the probe shown a goal, Aien would have been redundant and the gate fails Aien. The control is a gate in CI, not a one-off.

## 9. Gates and status

Status vocabulary: IMPLEMENTED / TESTED / QUALIFIED / SPECIFIED / PROPOSED / PLANNED / PARTIAL / ABSENT / BLOCKED_OPERATOR / NOT_RUN.

| gate | claim | status | where |
|---|---|---|---|
| G1 identity binding | subject id is content-addressed and bound to the LogicalAgentId; foreign root / agent refused | TESTED (host) | omega run.sh G1; aienos `t_resolve` |
| G2 restart persistence | a second process restores the same subject, intent and goal; AIEN assess wakes again | TESTED (host, process level) | omega run.sh G2; aienos `CK_CONTINUITY_SUBJECT_RESTART` (two processes, one sealed Store image) |
| G3 memory binding | only the journal whose lineage the subject names is accepted; fail closed | TESTED (host) | omega run.sh G3 |
| G4 model independence | models X, Y and none: same subject, intent, goal; bytes unchanged | TESTED (host) | omega run.sh G4 |
| G5 no authority, no orchestrator | symbol and source scan; loop inventory unchanged | TESTED (host) | omega run.sh G5; receipt |
| G6 negative control | 0 goals without Aien although the journal recorded everything | TESTED (host) | omega run.sh G6 |
| format refusals, replay, supersession, mismatch | unknown version, corruption, truncation, trailing bytes, origin refused; same bytes = same subject; one ACTIVE per slot; agent B is another subject | TESTED (host) | omega run.sh; aienos 150-check test; 4 mutants red |
| OS reboot | | NOT_RUN | |
| machine migration | | NOT_RUN, not claimed | |
| G7 native genesis | the AIENOS kernel creates the genesis subject inside the identity provisioning Store transaction (one `ss_transact`: AgentRoot, AgentState, Manifest 1, subject) and one standing intent as sequence 2; no host tool creates it | TESTED (QEMU) | aienos `M4_ALLEN` (planned rename: `M4_AIEN`) G7; host `test_continuity_subject_provision` |
| G8 exactly once | provisioning a provisioned Store is refused, image unchanged; restores never mint | TESTED (QEMU) | aienos `M4_ALLEN` (planned rename: `M4_AIEN`) G8, G11c |
| G9 QEMU cold restart | two restores, each a new `qemu-system-aarch64` process over the same emulated NVMe image: same subject, intent and lineage | TESTED (QEMU) | aienos `M4_ALLEN` (planned rename: `M4_AIEN`) G9 |
| G10 native persistence path | the restore request carries only the mode; ESP and UEFI vars rebuilt per boot; another image restores another subject; an independent reader decodes the head from the sealed Store; omega `allen publish` (planned rename: `aien publish`) of that head drives the AIEN goal | TESTED (QEMU) | aienos `M4_ALLEN` (planned rename: `M4_AIEN`) G10; receipt omega cross-check |
| G11 corruption does not re-provision | forked chain, flipped envelope, missing subject: refused or reported, nothing minted, image unchanged | TESTED (QEMU) | aienos `M4_ALLEN` (planned rename: `M4_AIEN`) G11; mutant `subject_restore_mints` KILLED |
| G12 foreign identity does not re-provision | another installation's subject chain is refused, never adopted | TESTED (QEMU) | aienos `M4_ALLEN` (planned rename: `M4_AIEN`) G12; mutant `subject_accept_foreign` KILLED |
| power loss during genesis | SIGKILL at all 9 Store checkpoints, then a cold boot: unprovisioned or identity with its genesis subject, never one alone | TESTED (QEMU + host) | aienos `M4_ALLEN` (planned rename: `M4_AIEN`) FI rows; host power cuts at every block boundary |
| hardware qualification (physical Spark NVMe, physical cold reboot) | | NOT_RUN | QEMU is not hardware |
| production path (kernel commits the object at a generation barrier; organism boot resolves it) | | PARTIAL | the kernel writes and restores the subject in the TEST continuity image (QEMU); the default image provisions no identity yet; organism boot does not yet read the subject from the kernel |
| multi-subject | | FUTURE, NOT IMPLEMENTED | |
| creed, §1.2 / §1.3 / §2.8 edits | | APPLIED (operator acceptance 2026-10-06) | |

Receipts (immutable; earlier ones unchanged): host v0 omega `evidence/ALLEN/83c62a41f0252d4b00de78dcad280b78827821c1181e0b02a0690403b8b4f085.json` (candidate `cda7609`, aienos lock `cd4b089`); host v0 after reconciliation omega `evidence/ALLEN/18cfa250cee91ce5abe4cba21fa9fb70da4df36b9b593924b86538dcdfdfabef.json` (candidate `6b78165`, aienos lock = merged aienos#259 `71d5b32`; merged as omega `b544d81`, same tree); native and QEMU aienos `evidence/allen_native_qemu_cfe9aecffb8b20e0c1ff51fad54c46c522ec7d6c56c6cba7661e4b8cda1ee25a.json` with `evidence/ck_gates_1ecf5bcd303bf88422dd0542f14851c931f5d52276838fa182c812f3c73f3c1b.json` (code commit `640522a`, aienos#260, merged as `9d41efc`). `ALLEN_V0_HOST`, `ALLEN_NATIVE_PROVISIONING` and `ALLEN_QEMU_COLD_RESTART` are separate results; QEMU is not a physical cold reboot.

## 10. Authority implications

None to the root. The AIENOS capability authority remains the only mint. Aien holds no capability reference and never appears as a subject of an authority decision. AEGIS verifies Aien's objects like any other objects and decides no policy. ARGUS may observe Aien state transitions.

## 11. Persistence implications

Aien is continuity kind 24 ([aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md)). Kinds 16 to 23 are unchanged; the resolver gains one pass per kind-24 object. ADR 0015's live-authority rule is unchanged: the in-memory copy is authoritative while running; storage is recovery material. The first subject object is written by the kernel inside the identity provisioning transaction ([aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md) §2.7), so no crash leaves an identity without its subject; restore resolves it read-only and never mints. The manifest link to the subject head and display of kind 24 by the recovery tools are FUTURE.

## 12. Interplane implications

`INTERPLANE IMPACT: NONE`. No wire change. INTERPLANE's runtime-side counterparty stays the runtime authority; Aien is Store state and World publication, never a party, adapter, dialect or transport. Carrying the subject id in the host-side `AuthorityContext` is a possible later cut and is not part of v0.

## 13. Backward compatibility

All existing receipts, milestone names and evidence are unchanged. Historical uses of "AIEN" in receipts stay. Stores without a kind-24 object resolve exactly as before. `rx_aien` is unmodified.

## 14. Risks

- Aien grows into an agent framework. Mitigated by I7 and gate G5 in CI.
- Doctrine churn in operator-confirmed documents. Mitigated: the only edits made before acceptance are two factual sentences in aienos and the model-generation naming in `doctrine/AIEN.md` §10.
- The abstraction is redundant. Tested by G6 on every CI run.
- Multi-subject questions get smuggled in. Deferred (I4).
- The production path is PLANNED, not built: today the host tool writes the object bytes; the kernel's `cs_commit` exists and is tested on a sealed Store image, but no boot path calls it yet.

## 15. Falsification criteria

The ADR is withdrawn if any of these holds: a standing intent survives restart and model swap without Aien (G6 shows a goal); Aien v0 cannot pass G1 to G6 without planner, router, UI or loop code (G5); or the binding of `LogicalAgentId` to the Cortex journal turns out to exist already in accepted code (re-checked 2026-10-04: aienos ADR 0016 kind 19 targets the legacy crate, ARCH-0022 reserves but does not define an identity; it did not exist).

## 16. One next step

Done in QEMU (G7 to G12, aienos `M4_ALLEN` (planned rename: `M4_AIEN`)). Next: give the default (production) AIENOS image an operator-approved identity provisioning path that calls `cs_provision`, so the same genesis and restore can run outside the TEST continuity image and then on the Spark's physical NVMe.
