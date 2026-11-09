# Causal id join, spec v0 (HD-08)

**Status:** DRAFT, 2026-10-01, hardening lane HD-08 part 1 (scout and spec, no code).
**Implements:** [ADR 0025](../adr/0025-execution-transcript-causal-id-resource-contract.md) section 2 ("One causal id chain"). This note turns the ADR's id table into a byte-level id format, a propagation rule and a join rule a verifier can apply. Where this note and ADR 0025 disagree on scope, the ADR wins.
**Byte home:** the record types proposed here belong in aien-protocols `specs/execution-transcript/TRN1_TRANSCRIPT_SPEC.md` (TRN1). Until that spec adopts them, they are proposals and no writer may emit them (TRN1 section 10: "A writer that needs a record this spec lacks proposes it here first; it does not invent a type number").
**Evidence base:** read-only fresh clones on 2026-10-01: aien-protocols `fdd288a` (TRN1 v0, aien-protocols#10), omega main `38919c8`, omega#176 head (OPEN, branch `hardening/LD-replay`, read as a diff only, not edited), omega#174 (MERGED, `tests/model/`), aienos `4a116e5`, aien-sovereign-core `ae89bbd` (includes sovcore#141). Paths are relative to the named repository. Line numbers in omega#176 files are line numbers in the new files as the PR adds them. Nothing in this note has run on any tier: every claim is a reading of source. Items that could not be checked in source are marked **UNVERIFIED**.

---

## In plain words

When something goes wrong, I want to start from a final receipt and walk back to the outside request that caused it, through every subsystem that touched it. Today each subsystem numbers its own work in its own way, and none of those numbers is passed to the next subsystem, so the walk stops at every boundary.

This note fixes three things:

1. **One cause id**: a 32-byte fingerprint created once, where an outside request first enters AIEN, and copied (never re-created) by everything downstream.
2. **Where it is written down**: three small new record kinds for the shared diary format (TRN1), so the cause id, the receipt link and the parent-child link between runs are in the diary, not only in memory.
3. **How a checker joins the diaries**: a step-by-step rule that either says "joined" or refuses with a named reason. It never guesses.

---

## 1. What each subsystem carries today (scout)

### 1.1 TRN1 v0 (aien-protocols `fdd288a`)

| Item | Where | What it is |
|---|---|---|
| run id | `specs/execution-transcript/TRN1_TRANSCRIPT_SPEC.md` section 3 (header offset 8, 32 bytes) | "opaque; the root causal id of this run (plan item P5). Any value." Not in the compared digest (section 4.2). |
| producer | same, header offset 40 | subsystem id of the writer (section 5.2 registry, ids 1 to 10) |
| seq, prev | section 4.1, record offsets 16 and 24 | dense 1-based position; record digest of the previous record (header digest for record 1) |
| branch ids | section 5.1, type 2 `BRANCH_CREATE` (branch u64, parent u64, generation u64), type 3 `BRANCH_DESTROY` | logical ids, local to the writer |
| effect id | section 5.1, types 9 and 10 | `effect u64` on intent and commit; the spec does not match commits to intents (section 11) |
| episode | section 5.3 | RxCrumb `episode` is **annotation only** (28-byte annotation: worker, t_start_ns, t_end_ns, episode), never compared |
| cause id | none | **No record type or field carries a cause id.** |
| receipt link | none | Section 11: "Anchoring the final digest in a signed receipt belongs to the receipt format, not to TRN1." |

### 1.2 omega runtime (main `38919c8`)

| Item | Where | Notes |
|---|---|---|
| crumb id | `src/runtime/rx_world.h` l.331 | 1-based, dense, per World |
| wake_cause | `rx_world.h` l.336 | crumb that last woke this activation |
| episode | `rx_world.h` l.351 to 355; set in `src/runtime/rx_world.c` l.200 to 203 | id of the EXTERNAL crumb that roots the wake chain, 0 if none. Derived, not hashed, checked by `rx_world_verify_crumbs` (`rx_world.c` l.307 to 308) |
| Cortex episode | `src/runtime/rx_cortex.h` l.281 (`CX_WREC_EPISODE`), l.298; read at `rx_cortex.c` l.516 | copies the crumb episode |
| J-Space branch | `src/runtime/rx_jspace.h` l.118 (`JsBranchRef {id u32, gen u32}`), l.233 to 236 (`branch_id`, `parent_branch` UINT32_MAX for root, `divergence_point`) | stable logical branch ref with generation |
| M22 dispatch.log | `src/train/tg_store.h` l.148 (`tg_dispatch(..., op_id, arg0, arg1, refs, n_refs)`), l.164 to 171 (`tg_dispatch_rec`: seq, step, base_gen, arg0, arg1, op_id, n_refs, refs, chain) | hash-chained per-dispatch records; no run id, no cause id |

### 1.3 omega#176 (OPEN, read-only here)

| Item | Where | Notes |
|---|---|---|
| RXCLOG01 file | `tools/replay/rxlog.h` l.13 to 16, l.47 to 49 | header `RXCLOG01`, version, flags; records CRUMB, INPUT, CHECKPOINT, END. **No run id field.** |
| crumb fields carried | `rxlog.h` `rxl_crumb` (id, kind, reaction, faculty, worker, wake_cause, coalesced, inputs, caps, outputs, reason, parents, t_start, t_end, episode, digest) | episode checked by rule: `tools/replay/rx_replay.c` l.143 to 146 (`world.episode` divergence); recomputed in `tools/replay/rxlog.c` l.278 |
| input ordering | `rxlog.h` l.49 (`RXL_FLAG_INPUTS`); rule in `rx_replay.c` header comment | every EXTERNAL crumb directly preceded by its INPUT record. This adjacency rule is the precedent for the CAUSE adjacency rules below. |
| capability generations | `tools/replay/rx_crumb_export.h` l.16 to 23 | stored **relative to the run's capability office generation** because raw generations are boot-seeded; raw runtime crumb digests therefore never repeat across runs |
| TRN1 run id | `tools/replay/trn1.c` l.259 to 260 | **run id = RXCLOG END head** (a digest of the content). Two identical runs get the same run id. See discrepancy D1. |
| TRN1 producer | `trn1.c` l.264 | omega-world (1) |
| crumb annotation | `trn1.c` l.294 | worker, t_start, t_end, episode, as TRN1 section 5.3 says |
| inputs | `trn1.c` l.301 | EXTERNAL_INPUT with source 1, input_seq = running count, subsystem external (10) |
| M22 dispatch | `rx_replay.c` l.294 onward (`verify-dispatch`, `compare-dispatch`), field list at l.368 to 375 (magic, op_id, seq, step, base_gen, arg0, arg1, n_refs, refs, base_digest, chain) | verified in its native form only; **no TRN1 export of dispatch.log** |

### 1.4 omega World lifecycle model (omega#174, merged, `tests/model/`)

| Item | Where | Notes |
|---|---|---|
| lifecycle | `tests/model/world_model.h` l.2 to 7 | wake, admit (charge), run, commit / invalidate / fail, reclaim (uncharge), cancel of a parent and its children |
| tree | `world_model.h` l.28 to 32; `tests/model/world_model.c` l.12 (`wm_parent = {-1, P, P, C1}`) | fixed four-reaction tree |
| state | `world_model.h` l.66 to 83 (`WmState`) | per-reaction status, `seq`, `wait_seq`, counters. **No activation id and no cause id**; cancel reaches children by the static tree. |

### 1.5 aienos (`4a116e5`)

| Item | Where | Notes |
|---|---|---|
| receipt | `native/kernel/artifact/ck_artifact.h` l.166 to 180 (`struct cka_receipt`: seq, nonce, time, id[32] and other digests, generation, context) | `id` is the artifact identity digest, not a request id |
| receipt seq | `native/kernel/core/artifact_loader.c` l.825 (`static uint64_t receipt_seq = 1`), l.990 to 998 (`print_receipt`) | minted **when the receipt is printed, after the run**, from a per-boot counter. `rc.generation` and `rc.context` are not set in `print_receipt` (zero from `memset`, l.993). |
| ARGUS event | `native/argus/argus_abi.h` l.219 to 237 | 128 bytes: sequence (producer-local), tick, principal, cap_id, cap_generation, world_generation, machine_id, `evidence_digest` (off 96) |
| kernel ARGUS emission | `native/kernel/svc/security.c` l.178 (`argus_check`) | builds synthetic events for a self-test; no other kernel `.c` outside `native/argus/` emits ARGUS events (grep, 2026-10-01) |
| task id | `native/kernel/core/sched.h` l.25 to 30 (`struct ck_task {uint32_t id; ...}`) | a slot; ADR 0025 section 2 says it is never the cause id |
| TRN1 | none | no file in aienos mentions TRN1 (grep, 2026-10-01) |

### 1.6 aien-sovereign-core (`ae89bbd`)

| Item | Where | Notes |
|---|---|---|
| TRN1 reader | `crates/aien-replay/src/lib.rs` l.89 to 91 (`Accepted { records, run_id, final_digest, compared }`), l.211 (run id read from header) | sovcore#141, merged; reads and verifies, emits nothing |
| control envelope | `crates/aien-runtime/src/control.rs` l.65 to 71 (`request_id u64`, `operation_id u128`, `operator_session u64`) | `operation_id` is supplied by the caller; the integration test makes one from the wall clock (`crates/aien-runtime/tests/runtime_spine_integration.rs` l.123) |
| world fork | `crates/aien-runtime/src/world.rs` l.118 to 140 (`fork_world(parent_id, timestamp)`, `child_id = next_world_id`, `parent: Some(parent_id)`) | parent link exists in memory; no transcript event |
| request id | `crates/aien-scheduler/src/lib.rs` l.122 (`submit_request`), l.132 to 133 | a caller-supplied `request_id` is used as the sequence id when its upper 32 bits are nonzero; otherwise the arena assigns one (**UNVERIFIED**: the else branch was not read line by line) |
| sequence ids | `crates/aien-runtime/src/sequence.rs` l.7, `crates/aien-scheduler/src/sequence.rs` l.11, `crates/aien-campaign-verifier/src/ids.rs` l.9 | **three** `SequenceId` types (ADR 0025 counted two), see D3 |

---

## 2. The causal id chain

### 2.1 Ids and who mints them

All ids below are 32 bytes unless stated. Hash is SHA-256. Integers are little-endian, as in TRN1.

| Id | Format | Minted by (only here) | Compared on replay? |
|---|---|---|---|
| **run id** | `SHA-256("AIEN_RUN_V0" \|\| producer u16 \|\| source commit (20 bytes) \|\| opener nonce (16 bytes))` | the transcript writer, once, when it opens the transcript | No. TRN1 already leaves the header out of the compared digest (section 4.2). A replay gets a new run id. |
| **cause id** | `SHA-256("AIEN_CAUSE_V0" \|\| subsystem u16 \|\| local_kind u32 \|\| local u64 \|\| root digest (32))` | the admission point that accepts an outside input with no cause attached (table 2.2) | Yes. Every field is deterministic for the same history, so a correct replay reproduces it. |
| **step reference** | (run id, seq) | the transcript | seq yes, run id no |
| **branch id** | TRN1 `BRANCH_CREATE.branch` u64, local to the writer | the component that creates the branch | Yes |
| **effect id** | TRN1 `EFFECT_INTENT.effect` u64 | the effect broker at intent time (ADR 0025 section 2) | Yes |
| **receipt digest** | SHA-256 of the receipt bytes, per receipt format | the receipt writer | No (carried in an annotation, section 3.2), because receipt bytes may hold values that differ between correct runs (**UNVERIFIED** for each receipt format) |

The opener nonce makes two runs of identical work get different run ids, which ADR 0025 section 2 needs ("one transcript"). Its source per subsystem is **UNVERIFIED**: omega host tools can read the host's random source; whether the aienos kernel has an entropy source fit for this was not checked. A writer with no nonce source refuses to open a transcript; it does not fall back to a content digest.

### 2.2 Root digest per subsystem (what the cause id is minted over)

| Subsystem | local_kind | local | root digest | Mint point |
|---|---|---|---|---|
| omega World | 1 = omega episode | episode (the EXTERNAL crumb id) | SHA-256 of the encoded external input **with the capability generation in the relative form** of omega#176 (`rx_crumb_export.h` l.16 to 23) | World external publication (`rx_world.c`, the EXTERNAL crumb path near l.200) |
| aienos | 2 = aienos admission | admission ordinal, counted at admission, not at receipt print | the artifact identity digest (`cka_receipt.id` source, `r->b.id`) | artifact admission (`native/kernel/artifact/admission.c`, `artifact_loader.c`) |
| sovereign-core | 3 = sovcore request | the one `SequenceId` the boundary settles on (ADR 0025 section 2), packed to u64 | SHA-256 of the request bytes as received (**UNVERIFIED**: no canonical request encoding exists yet) | `Scheduler::submit_request` or the control spine, whichever sovereign-core names as its admission point |

Raw omega crumb digests must not be used as a root digest: the capability generations in them are boot-seeded and never repeat across runs (omega#176 `rx_crumb_export.h` l.16 to 23), so a replay could never reproduce the cause id. The relative form is the one TRN1 already compares.

### 2.3 Propagation

1. **Mint once.** An admission point mints a cause id only when the input arrives from outside AIEN with no cause attached.
2. **Copy across a boundary.** When one AIEN subsystem hands work to another (sovcore request into an omega World publication, omega effect into an aienos admission), the handoff carries the cause id and the origin run id. The receiving admission point records it as ADOPT (section 3.1) and does not mint.
3. **Refuse a missing cause.** An admission point that receives work from another AIEN subsystem without a cause id refuses the work (ADR 0025 section 2: "A component that needs an id it was not given refuses; it does not mint a substitute"). It records the refusal.
4. **Inside omega,** every crumb already names its episode by rule (`rx_world.c` l.200 to 203), so crumbs need no new field: the join derives the cause from the episode.
5. **Effects and branches** name their cause with a CAUSE REF record written immediately before them (section 3.1).
6. **Receipts** name the cause id and run id inside the receipt bytes once each receipt format is revised (cuts A2, and sovereign-core `aien-proof` **UNVERIFIED**), and the transcript binds the receipt digest with RECEIPT_BIND.
7. **ARGUS** keeps its 128-byte ABI. An ARGUS event joins a cause only through `evidence_digest` (`argus_abi.h` off 96) equal to a receipt digest that a RECEIPT_BIND names (ADR 0025 section 2, "ARGUS ABI is not changed").

### 2.4 Parent and child: branches and Worlds

- **Branch inside one run** (omega J-Space fork, sovcore KV fork): `BRANCH_CREATE` (TRN1 type 2) with `parent` = the parent branch id (0 for a root). J-Space maps `JsBranchRef {id, gen}` (`rx_jspace.h` l.118) to `branch = id`, `generation = gen`, `parent = parent_branch + 1` with UINT32_MAX (root, l.234) mapped to 0. The record is preceded by a CAUSE REF naming the cause the fork serves. A branch never mints a cause; all work in it serves its creator's cause.
- **Child World that writes its own transcript** (sovcore `fork_world`, `world.rs` l.118; a forked omega World): the parent transcript holds `BRANCH_CREATE` for the child, and the child transcript's record 1 is RUN_LINK (section 3.3) pointing back at it. The child gets a new run id. Causes flow parent to child by ADOPT, never by a new mint.
- **Cancel** (omega#174 model: cancel reaches every descendant, `world_model.h` l.5 to 7, invariant I2): a cancel serves the cancelled unit's cause. Cancelling a parent writes one cancel event per descendant, each with the descendant's cause. The cancel record itself belongs to the resource-contract spec (ADR 0025 section 5, plan item P2); this note fixes only that it carries a cause and never mints one.
- **Replay is not a parent.** A replay gets a new run id and no RUN_LINK; the replay relation lives in the verifier's input (two files) and in the replay receipt, never inside the transcript, so that a correct replay compares MATCH record for record.

---

## 3. Proposed TRN1 records (for aien-protocols, not yet valid)

Type numbers 17 to 20 are proposals for TRN1 0.2.0 (table and arch#96 coordination in section 3.5). Until that spec version exists, these records are refused as UNKNOWN by every conforming reader (TRN1 refusal -5), which is correct.

### 3.1 Type 17 CAUSE (ident 80)

| Field | Size | Rule |
|---|---|---|
| cause | 32 | the cause id |
| mode | u32 | 1 MINT, 2 ADOPT, 3 REF; else SHAPE |
| local_kind | u32 | table 2.2 (1 to 4) for MINT and ADOPT. For REF it is **0 exactly**; any other value is SHAPE. Decided here (Q3): PR #12 left it open and its verifier accepts 0 to 4 for REF (`trn1_verify.c` l.281 to 282 at e0dccc7); the REF cause field already names the cause, so a second copy of its source would let two correct writers emit different REF bytes for the same cause and DIVERGE. This follows the root-digest rule in the last row. |
| local | u64 | table 2.2, nonzero, for MINT and ADOPT. For REF it is **0 exactly**; nonzero is SHAPE (Q3, decided here, same reason). |
| root digest | 32 | MINT: the digest the cause was minted over; ADOPT and REF: zero (NONCANONICAL otherwise) |

Rulings on the TRN1 0.2.0 open questions (aien-protocols PR #12 body, items 2 to 5 and 7; judged in the HD-08 S1 inspector report). Each says whether PR #12 or this note decides it. Q1 (schema number) is recorded in section 3.5, rule "Wire schema".

- **Q3, REF fields.** Decided here: REF local_kind and local are zero, see the table above. PR #12 must tighten its verifier to match (today it accepts 0 to 4 and any local for REF).
- **Q5, cause recompute subsystem.** Decided here: the join recomputes a cause id with the **subsystem of the CAUSE record itself** (the record header subsystem field, TRN1 section 5.2), not the file header producer. The record names the admission point that minted the cause; the header names only the file writer, and the two can differ (for example a sovereign-core file holding a cause minted by an omega admission). PR #12 left this open; its goldens use equal values, so it already satisfies this rule.
- **Q7, reorder.** Decided here: for local_kind 2 and 3 the placement check (step 4) also requires that no earlier record in the same file names the cause (an earlier REF, RESOURCE cause field or RECEIPT_BIND). A MINT or ADOPT written after the record that uses its cause is `CAUSE_PLACEMENT` at the late CAUSE record, because step 4 runs before step 7 and the first failing step decides. `REF_UNKNOWN` stays for a REF or RESOURCE whose cause has no MINT or ADOPT at all in the run (omission, or a flipped cause byte). So reorder vector f008 refuses with `CAUSE_PLACEMENT` at event 2 (its CAUSE MINT).

Annotation (never compared): ADOPT carries origin run id (32) and origin seq (u64), naming the CAUSE record that minted or adopted it upstream.

Placement rules (adjacency, as omega#176 `RXL_FLAG_INPUTS` does for inputs):
- MINT and ADOPT with local_kind 1 (omega episode) immediately follow the `RX_CRUMB` whose crumb id equals `local` and whose kind is EXTERNAL.
- MINT and ADOPT with local_kind 2 or 3 immediately precede the first record that does work for that admission, and no earlier record in the file may name that cause (Q7 above).
- REF immediately precedes exactly one `EFFECT_INTENT`, `BRANCH_CREATE` or `BRANCH_DESTROY`.

### 3.2 Type 18 RECEIPT_BIND (ident 40)

| Field | Size | Rule |
|---|---|---|
| cause | 32 | a cause opened earlier in this transcript |
| format | u32 | 1 aienos `cka_receipt`, 2 omega evidence receipt, 3 sovereign-core `aien-proof`; else SHAPE |
| reserved | u32 | zero |

Annotation: receipt digest (32). It is chained (the annotation is inside the record digest) but not compared.

### 3.3 Type 19 RUN_LINK (ident 48)

| Field | Size | Rule |
|---|---|---|
| relation | u32 | 1 CHILD_OF; else SHAPE |
| reserved | u32 | zero |
| parent branch | u64 | the `branch` of the parent's `BRANCH_CREATE` |
| parent create digest | 32 | compared digest of that `BRANCH_CREATE` record |

Annotation: parent run id (32), parent seq (u64). Allowed only as record 1.

### 3.4 M22 dispatch.log

TRN1 v0 has no record type for an M22 dispatch record, and omega#176 verifies `dispatch.log` only in its own form (`rx_replay.c` l.294 onward). A dispatch record needs a TRN1 type before it can join the chain. Proposed for the same spec revision: type 20 TRAIN_DISPATCH, identity = candidate: the 160 hashed bytes of the record (`D_SIZE` 192, `D_HASHED` 160, `rx_replay.c` l.765 to 766 at omega#176 head 9112e2b). The chain field is not subtracted: it sits at bytes 160 to 191 (`rx_replay.c` l.841), outside the 160 hashed bytes (`sha256_update(&c, rec, D_HASHED)`, l.817). An earlier draft said "160 hashed bytes minus the chain field", which was self-inconsistent. **Decided here (Q2):** TRN1 0.2.0 reserves the number 20 and defines no layout, as PR #12 implemented (type 20 is refused UNKNOWN under every schema, vector m071). The candidate identity above, which would compare op_id, seq, step, base_gen, args, refs and (only if replay-stable) base_digest, is fixed only in a later TRN1 version after omega#176 merges and the base_digest stability below is checked. A training run then opens one cause (local_kind 4, train run, root digest = generation 0 digest) and every dispatch serves it. **UNVERIFIED**: whether `base_digest` is replay-stable across two correct training runs.

### 3.5 Coordination with resource-contract-v0 (arch#96)

arch#96 (`docs/hardening/resource-contract-v0.md`, branch `hive/HD-09-resource-contract-spec`) proposes a `RESOURCE` record for TRN1 0.2 without a type number ("number assigned there") and with an 8-byte `cause` field. The two proposals go to aien-protocols as **one** TRN1 0.2.0 version bump, with this single number table:

| Type | Name | ident_len | Proposed by |
|---|---|---|---|
| 17 | CAUSE | 80 | this note, section 3.1 |
| 18 | RECEIPT_BIND | 40 | this note, section 3.2 |
| 19 | RUN_LINK | 48 | this note, section 3.3 |
| 20 | TRAIN_DISPATCH | none in 0.2.0: number reserved, refused UNKNOWN (Q2, section 3.4) | this note, section 3.4 |
| 21 | RESOURCE | 96 | arch#96 section 4 |

Rules for the shared bump:

- `RESOURCE.cause` is the **32-byte cause id** of section 2.1, not a u64. With that change the arch#96 identity is op u8, reason u8, field u16, reserved u32, unit u64, cause (32), contract (32), declared u64, used u64 = 96 bytes. The arch#96 builder is aligning its side to match.
- A `RESOURCE` record's cause must be open in the same run (minted or adopted earlier, section 3.1), checked as step 7 of the join rule checks a CAUSE REF: `REF_UNKNOWN` otherwise. A cancel of a descendant carries the descendant's cause (section 2.4).
- **Wire schema.** TRN1 0.2.0 files use header schema number **3**. Schema 2 is never assigned, because a 0.2 file under schema 2 would flip the verdict of existing 0.1 vector m020, which pins schema 2 as refused (aien-protocols PR #12, TRN1 spec section 10). The contract version (0.2.0) and the wire schema number are separate fields; this note names only the contract version.
- Neither proposal takes a number outside this table. If aien-protocols renumbers, both notes follow its numbers.
- Corpus vectors for types 17 to 21 ship in the same aien-protocols change (cut S1).

---

## 4. The join rule

Input: a set of TRN1 files and a set of receipt files. Output: exactly one line.

```
JOINED runs=<R> causes=<C> records=<N> receipts=<B> argus_joined=<J> argus_unjoined=<U>
JOIN_REFUSED reason=<CODE> run=<64 hex> event=<k> [detail]
```

Steps, in this order. The first failing step decides the outcome.

1. **Verify each file** with the TRN1 verifier (omega `tools/replay/trn1.c` once omega#176 merges, or sovereign-core `aien-replay`). A refused file refuses the join: `TRANSCRIPT`.
2. **Index by run id.** Two files with the same run id: `DUP_RUN`.
3. **Check every CAUSE MINT:** recompute the cause id from (the CAUSE record's own subsystem, local_kind, local, root digest; Q5); mismatch: `CAUSE_DIGEST`. The same cause minted twice anywhere in the set: `DOUBLE_MINT`.
4. **Check placement** (section 3.1): `CAUSE_PLACEMENT`.
5. **Check every ADOPT:** the origin run named in its annotation must be in the set, and the record at origin seq must be a CAUSE MINT or ADOPT with the same cause. Origin run not supplied: the join is not refused but reports that cause as `NOT_RUN reason=origin_missing` and does not count it as joined. Origin present but record wrong: `ADOPT_ORIGIN`.
6. **Check every RX_CRUMB:** its episode (re-derived by the omega rule, as omega#176 `rx_replay.c` l.143 checks) must be 0 or name a crumb that has a CAUSE MINT or ADOPT right after it: `EPISODE_UNCAUSED`. Episode 0 crumbs (no outside publication) are allowed and counted as uncaused.
7. **Check every EFFECT_INTENT, BRANCH_CREATE, BRANCH_DESTROY:** it must be preceded by a CAUSE REF (a RESOURCE record instead names its cause in its own 32-byte field, which must be open in this run) whose cause is open in this run (minted or adopted earlier, or, for a child run, adopted from its parent): `REF_MISSING` or `REF_UNKNOWN`. Each EFFECT_COMMIT must match an earlier intent with the same effect id in the same run: `COMMIT_ORPHAN` (TRN1 v0 leaves this to replayers, section 11).
8. **Check every RUN_LINK:** the parent run must be in the set, and the parent's record at the annotated seq must be a BRANCH_CREATE whose compared digest and branch match: `RUN_LINK`. Parent not supplied: `NOT_RUN reason=parent_missing` for that child, as in step 5.
9. **Check every RECEIPT_BIND:** the cause must be open in this run: `RECEIPT_CAUSE`. A receipt file whose SHA-256 equals the annotated digest must be supplied, else `NOT_RUN reason=receipt_missing`. Once receipt formats carry cause and run (cut A2), the receipt's own cause id and run id must equal the bind's cause and the transcript's run id: `RECEIPT_MISMATCH`. Before cut A2 lands, that last check is reported NOT_RUN with reason `receipt_format_v0`, never as a pass.
10. **ARGUS:** an `ARGUS_EVENT` whose `evidence_digest` equals a bound receipt digest is joined to that receipt's cause. Others are counted as `argus_unjoined`, which is allowed (ADR 0025 section 2 keeps ARGUS separate from World state).

The join line never says JOINED while any step reported NOT_RUN for a cause; it then prints `JOINED_PARTIAL` with the same counts plus `not_run=<n>`.

### 4.1 Refusal cases (summary)

| Code | Means |
|---|---|
| TRANSCRIPT | a file fails TRN1 verification |
| DUP_RUN | two files claim the same run id |
| CAUSE_DIGEST | a minted cause id does not recompute |
| DOUBLE_MINT | one cause minted twice |
| CAUSE_PLACEMENT | a CAUSE record is not where section 3.1 requires |
| ADOPT_ORIGIN | an adopted cause does not match its origin record |
| EPISODE_UNCAUSED | a crumb's episode has no cause |
| REF_MISSING / REF_UNKNOWN | an effect or branch names no cause, or a cause not open in this run |
| COMMIT_ORPHAN | an effect commit with no intent |
| RUN_LINK | a child run's link does not match its parent |
| RECEIPT_CAUSE / RECEIPT_MISMATCH | a receipt bound to a cause not open, or a receipt naming a different cause or run |

Each code needs a broken example in the corpus that produces it (ADR 0025 section 4, "Every check has a counterexample"): drop a CAUSE, swap two CAUSE records, flip a byte of a root digest, duplicate a MINT, point an ADOPT at the wrong seq, remove a REF, bind a receipt to an unopened cause, edit a receipt's cause.

---

## 5. Field mapping, have and missing

| Subsystem | run id | cause id | step ref | branch / parent | effect id | receipt names cause + run |
|---|---|---|---|---|---|---|
| TRN1 v0 | HAVE (header, opaque) | MISSING (no field) | HAVE (seq, prev) | HAVE (`BRANCH_CREATE`) | HAVE (u64) | MISSING (by design, section 11) |
| omega runtime | MISSING | PARTIAL: `episode` local u64, derived (`rx_world.c` l.200) | HAVE (crumb id, wake_cause, parents) | HAVE in J-Space (`JsBranchRef`, `parent_branch`); no transcript event | MISSING (effect result ring unused, ADR 0025 Context) | MISSING |
| omega#176 export | PRESENT but content-derived (`trn1.c` l.259 to 260), see D1 | MISSING; episode in annotation only (`trn1.c` l.294) | HAVE | MISSING (no BRANCH_CREATE export) | MISSING | n/a |
| omega M22 dispatch.log | MISSING | MISSING | HAVE (seq, chain) | n/a | n/a | MISSING; no TRN1 type |
| omega World model (#174) | n/a | MISSING (no activation or cause id) | `seq`, `wait_seq` only | static `wm_parent` tree | n/a | n/a |
| aienos kernel | MISSING | MISSING; receipt `seq` minted after the run (`artifact_loader.c` l.990) | ARGUS `sequence` per producer | n/a | MISSING | MISSING (`cka_receipt` has no field; `context` u64 unset) |
| aienos ARGUS | n/a | link only via `evidence_digest` | HAVE (`sequence`, chain) | n/a | n/a | n/a |
| sovereign-core | read only (`aien-replay` `Accepted.run_id`) | PARTIAL: caller-supplied `operation_id` u128 and `request_id` u64 | three `SequenceId` types | HAVE in memory (`fork_world` parent) | MISSING | MISSING (**UNVERIFIED** for `aien-proof`) |

---

## 6. Discrepancies (code versus plan)

Recorded, not fixed here. Code beats plans.

- **D1.** omega#176 sets the TRN1 run id to the RXCLOG END head (`tools/replay/trn1.c` l.259 to 260). That is content-derived: two identical runs share a run id, which breaks "one run id per transcript" (ADR 0025 section 2, "minted by the transcript recorder when the run opens"). TRN1 v0 allows any value, so this is not a TRN1 violation. Cut O1 fixes it after merge.
- **D2.** aienos mints the receipt `seq` at print time from a per-boot counter (`artifact_loader.c` l.825, l.990), not at admission. ADR 0025's table lists `cka_receipt.seq` as a cause id source; it cannot be one, because it does not exist while the work runs.
- **D3.** sovereign-core has three `SequenceId` types (runtime, scheduler, campaign verifier), not two as ADR 0025 says.
- **D4.** sovereign-core accepts caller-supplied ids (`request_id` used as the sequence id when its upper 32 bits are nonzero, `lib.rs` l.132; `operation_id` from the caller, `control.rs` l.68). Under this spec those are ADOPT inputs and must carry an origin; today nothing checks one.
- **D5.** TRN1 v0 has no place for a cause id; the omega episode survives only as an uncompared annotation.
- **D6.** The kernel feeds ARGUS only synthetic self-test events (`security.c` l.178), as ADR 0025 already records.

---

## 7. Code cuts owed

Each cut is about one file. "After 176" means it edits files omega#176 adds and must wait for that PR to merge; this lane does not touch omega until then.

| Cut | Repo, file | Change | Waits for |
|---|---|---|---|
| S1 | aien-protocols `specs/execution-transcript/TRN1_TRANSCRIPT_SPEC.md` + `vectors/` | TRN1 0.2.0 (one bump shared with arch#96): types 17 CAUSE, 18 RECEIPT_BIND, 19 RUN_LINK, 21 RESOURCE with a 32-byte cause, and number 20 TRAIN_DISPATCH reserved without a layout (Q2), under header schema 3; corpus goldens and one broken vector per refusal code in section 4.1 | nothing (spec owner) |
| O1 | omega `tools/replay/trn1.c` | `trn1_from_rxlog` takes the run id from its caller (minted per section 2.1) instead of the END head | 176 |
| O2 | omega `tools/replay/trn1.c` (or new `tools/replay/trn1_cause.c`) | emit CAUSE MINT after each EXTERNAL `RX_CRUMB`, root digest over the relative-generation input | 176, S1 |
| O3 | omega new `tools/replay/trn1_join.c` | the join rule of section 4, one output line, wired as `rx_replay join` | 176, S1 |
| O4 | omega `tests/replay/run_replay_suite.sh` | run the join over the S1 corpus; every broken vector must refuse with its code | O3 |
| O5 | omega `tools/replay/rx_replay.c` or new `tools/replay/dispatch_trn1.c` | export M22 `dispatch.log` to TRN1 TRAIN_DISPATCH under one train-run cause | 176, S1 |
| O6 | omega `src/runtime/rx_world.c` (runtime lane) | external publication accepts an adopted cause id and keeps it per episode; refuses an internal publication with no cause | S1; runtime lane coordination |
| O7 | omega `tests/model/world_model.c` | add a cause id per activation and an invariant "cancel of a descendant carries the descendant's cause, never a new one", with a mutant that mints a new one | nothing |
| A1 | aienos `native/kernel/core/artifact_loader.c` | count the admission ordinal and mint the cause at admission, carried in `struct report` to the receipt | S1; CK lane coordination |
| A2 | aienos `native/kernel/artifact/ck_artifact.h` + `receipt.c` | receipt revision carrying cause id and run id (versioned layout, old version refused) | A1 |
| A3 | aienos ARGUS emitter for admission (file **UNVERIFIED**, kernel emission lane) | admission ARGUS event sets `evidence_digest` = receipt digest | A2, real kernel emission |
| C1 | sovereign-core `crates/aien-replay/src/lib.rs` | second, independent join implementation over the same corpus | S1 |
| C2 | sovereign-core `crates/aien-scheduler/src/lib.rs` | `submit_request` takes a cause (ADOPT) or mints at the named admission point; refuses internal work without one | sovereign-core picks one `SequenceId` (D3) |
| C3 | sovereign-core `crates/aien-runtime/src/world.rs` | `fork_world` records BRANCH_CREATE with a CAUSE REF, child run starts with RUN_LINK | S1, a sovereign-core TRN1 writer |

## 8. Limits

- Nothing here has run. All results: NOT_RUN, reason MISSING_IMPLEMENTATION.
- omega#176 was read as an open PR diff; its line numbers may move before merge.
- The opener nonce source on aienos, the replay stability of each receipt format and of M22 `base_digest`, and a canonical sovereign-core request encoding are UNVERIFIED.
- Resource events (charge, refund, cancel) need the resource-contract spec (ADR 0025 section 5) before they can carry causes in TRN1.
