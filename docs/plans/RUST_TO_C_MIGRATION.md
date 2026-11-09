# Rust → C Migration Plan (decided 2026-09-27)

> **SUPERSEDED 2026-10-01 by [ADR 0024](../adr/0024-rust-scaffolding-omega-destination.md).** The decision "no Rust anywhere; C is the target" and the step order below no longer apply. Rust is scaffolding, Omega is the destination, and C stays only where hardware-justified. Kept unchanged as history.

**Decided by Drake 2026-09-27: no Rust anywhere; C (+asm where measured) is the target. Authority ported 2026-09-28 (aienos #156, omega #43).**

**Status:** the direction above is decided. The step order in §3 and the open items in §6 are still proposals awaiting Drake.

**Written:** 2026-09-28.

**Why this exists.** On 2026-09-27 Drake decided: no Rust anywhere, Aienux included. Everything comes from my own lineage, and existing Rust gets rewritten. On 2026-09-28 he agreed the target language is C, with hand-written assembly only where a measurement shows it is faster. This document proposes *how* to get there without breaking what already works.

**Words used below:**

- **Crate**: one Rust package, roughly one component or library.
- **C twin**: a C rewrite of one crate that must pass the same tests as the Rust original before the Rust is removed. Both exist side by side for a while, the way a new bridge is load-tested before the old one closes.
- **CI**: the automatic build-and-test that runs on GitHub for every proposed change.

---

## 1. How the numbers were counted

Every figure below was counted on 2026-09-28 from `origin/main` of each repository, not from a local working copy:

| Repository | Commit counted |
|---|---|
| aien-dev/aienux | `c8ab65e` |
| aien-spark/aien-sovereign-core | `63fe7a7` |
| aien-spark/aegis-runtime | `2bbce76` |
| aien-spark/omega (for the existing C crumb reader) | `ceb68d6` |

Method, so anyone can rerun it: list every tracked `.rs` file with `git ls-tree -r --name-only origin/main`, drop anything under `vendor/`, and count lines of each file with `git show origin/main:<file> | wc -l`. Line counts include comments, blank lines, and tests.

Only first-party code is counted. aienos also carries **1,469 vendored `.rs` files** (outside libraries copied into `vendor/`: `libc`, `uefi`, `syn`, `serde`, `curve25519-dalek`, `ed25519-dalek`, `sha2`, and others). They are not counted as work to port. They disappear on their own once nothing in aienos is built with Rust.

The totals match the earlier estimates (aienos ~58k, sovereign-core ~91k, aegis-runtime ~9k lines).

---

## 2. Inventory

### 2.1 aienos: 151 files, 57,714 lines

| Crate | Files | Lines | What it depends on (first-party / outside) |
|---|---:|---:|---|
| aienos-kernel | 83 | 37,849 | capability, accel, artifact, crypto |
| aienos-boot | 7 | 4,580 | kernel, accel; outside: `uefi` 0.41 |
| aienos-artifact | 12 | 2,505 | crypto; outside: `ed25519-dalek` |
| aienos-accel | 5 | 2,218 | none |
| aienos-aegis | 7 | 1,757 | kernel, agent-state, cortex; outside: `serde`, `serde_json` |
| aienos-evidence | 9 | 1,728 | kernel; outside: `serde_json` |
| aienos-agent-state | 7 | 1,440 | kernel; outside: `serde`, `serde_json` |
| aienos-artifact-tool | 3 | 1,319 | artifact, crypto; outside: `ed25519-dalek`, `serde`, `serde_json` |
| aienos-capability | 1 | 1,001 | none. **Already has a C twin** (see below) |
| aienos-crypto | 5 | 922 | none (own AES, AES-GCM-SIV, POLYVAL, SHA-256) |
| aienos-cortex | 5 | 728 | kernel; outside: `serde`, `serde_json` |
| aienos-c1-tree | 5 | 721 | kernel, agent-state; outside: `serde`, `serde_json` |
| aienos-store-tool | 1 | 477 | kernel |
| aienos-capability-ffi | 1 | 469 | capability (the bridge that let C call the Rust authority) |

Things worth knowing inside those numbers:

- **The kernel is two-thirds of aienos.** Its biggest parts are the artifact loader (1,699 lines plus 1,615 lines of tests), the SMMU, the NVMe driver, the device layer, the ABI, and user-space handling. It also has 9 test files, 4,683 lines, in `crates/aienos-kernel/tests/`.
- **"Store" is not its own crate.** System Store v1 is a module inside the kernel (`src/store.rs` and `src/store/`, 3,487 lines), plus the 477-line `aienos-store-tool`. It has golden-vector and negative tests (`store_v1_golden_vectors.rs`, `store_v1_negative.rs`).
- **Crypto is the bottom of the stack.** The kernel and artifact both link it, and it depends on nothing. Signature checking (Ed25519) is *not* in it: it comes from the vendored `ed25519-dalek` and `curve25519-dalek`.
- **The capability authority is already done.** `native/capability/` is the C version, with 336 unit checks. It matched the Rust crate over 1M random operations (aienos #156). Omega R7/R9 already link it (omega #43). The Rust `aienos-capability` stays only because `crates/aienos-kernel/src/caps.rs` re-exports it (`pub use aienos_capability::{...}`).

### 2.2 aien-sovereign-core: 298 files, 90,657 lines

| Crate / folder | Files | Lines |
|---|---:|---:|
| aien-inference-abi | 35 | 15,431 |
| aien-cli | 25 | 10,040 |
| **crumbs** | **27** | **8,465** |
| spark-adapters | 18 | 7,044 |
| cortex-rs | 13 | 7,025 |
| aien-proof | 15 | 6,743 |
| spark-cockpit-rs | 1 | 3,851 |
| aien-runtime | 17 | 3,368 |
| spark-hive | 5 | 2,727 |
| aien-scheduler | 4 | 2,629 |
| spark-inquisitor | 14 | 2,431 |
| e2e_tests/tests | 4 | 2,303 |
| spark-mail-rs | 10 | 2,174 |
| aien-kv-cache | 2 | 1,849 |
| aien-mcp | 11 | 1,447 |
| cortex-path-m1 | 9 | 1,304 |
| aien-campaign-verifier | 8 | 1,239 |
| benchmarks/crates | 7 | 1,172 |
| spark-harvester | 8 | 1,113 |
| spark-crumbs | 2 | 963 |
| spark-dream | 2 | 783 |
| aien-platform-linux | 6 | 760 |
| spark-debugger | 5 | 639 |
| spark-discord-hub | 6 | 613 |
| spark-harness | 2 | 608 |
| cortex-encoder-rs | 1 | 535 |
| aien-security | 4 | 492 |
| spark-supervisor | 4 | 468 |
| aien-platform | 8 | 438 |
| spark-max-rs | 1 | 407 |
| aien-inference-runtime | 4 | 397 |
| rad-id-sync | 5 | 382 |
| aien-capability | 5 | 240 |
| e2e_tests/src | 2 | 233 |
| spark-max-cabi | 2 | 212 |
| aien-inference-service | 6 | 132 |

The 298 files include two folders that are not crates: `e2e_tests/` (6 files, 2,536 lines) and `benchmarks/crates` (7 files, 1,172 lines).

`spark-crumbs` is a different, older crate from `crumbs`. Several crates (cortex-rs, spark-hive, spark-inquisitor, spark-adapters) pull it from the separate `aien-spark/spark-crumbs` repository. No crate in sovereign-core depends on `crumbs` (Crumb v1). `crumbs` stands alone and is used as its own programs (`crumbs`, `crumbs-probe-learner`).

### 2.3 aegis-runtime: 53 files, 9,207 lines

| Folder | Files | Lines |
|---|---:|---:|
| src | 46 | 7,274 |
| tests | 6 | 1,901 |
| build.rs | 1 | 32 |

This is the standalone `aien-spark/aegis-runtime` repository. It is **not** the same thing as aienos's `crates/aienos-aegis` (1,757 lines), which is counted under aienos above.

### 2.4 Not counted

- The ~20 other aien-dev repositories that are mainly Rust. They are not inventoried here (see §6).
- `crates/spark-aegis` in sovereign-core is a symlink to a folder on the Spark that is not a git repository (already noted in `CURRENT_CODE_TO_R0_R16_MIGRATION.md` §3.4). There is nothing tracked to count.

---

## 3. Proposed order

The rule for every step is the same. **Write the C twin, prove it passes the same tests as the Rust, keep both running for a while, then remove the Rust.** Nothing is deleted before the twin has passed in CI.

### Step 1: Crumb v1 → C, inside omega `src/crumbline`

**Why first:** it is small (8,465 lines), nothing else in Rust depends on it, and omega already has part of it in C.

**What exists today.** Omega has about 1,200 lines of C in `src/crumbline/` (`cl_common`, `cl_crumb`, `cl_program`, `cl_search`). That is only the *learner side*: the visible-crumb reader and Omega's search. Everything else in Crumb v1 exists only in Rust: generators, sealed verifier, mixer, ledger, promotion ladder, trace, audit, session, CLI.

**Correction to the premise.** This plan was briefed as "omega already owns the format spec". It does not yet. `omega/spec/crumbline.md` says the contracts live in sovereign-core `crates/crumbs/SPEC.md` and that omega "implements only the consumer adapter". So step 1 is also a *move of ownership*: the Crumb v1 spec moves into omega, and omega becomes the owner.

**What the C twin must do:**

1. Move `crates/crumbs/SPEC.md` into omega `spec/` as the single source of truth.
2. Port the generators, sealed verifier, mixer, ledger, promotion, trace, and CLI to C under `src/crumbline/`.
3. **Keep the sealed side separate from the learner.** `tests/crumbline/run_conformance.sh` already checks that the `crumbline-learner` program contains no sealed-side code. That is the anti-cheating wall: the learner must never be able to see answers. The sealed C code has to be a separate program in omega's Makefile, never linked into `crumbline-learner`.
4. **Generate the test vectors from C.** Today the 19 vectors in `tests/crumbline/vectors/` are produced by the *Rust* `crumbs vectors` command. The C twin must produce byte-identical vectors itself, or the Rust can never be removed.
5. Pass the same tests as the Rust crate (`tests/boundary.rs`, `tests/curriculum.rs`, `tests/generators.rs`) and reproduce `tests/golden_registry_digest.txt` exactly.

**Outside libraries to replace:** `blake3`, `serde`/`serde_json`, `uuid` (v7). See §6 for the choices this raises.

**Done when:** the C programs produce identical vectors and digests to the Rust ones, all ported tests pass in omega CI, and then `crates/crumbs` is removed from sovereign-core.

### Step 2: aegis-runtime is retired at R16, not ported

`CURRENT_CODE_TO_R0_R16_MIGRATION.md` §3.5 already classifies aegis-runtime as legacy orchestration: an LLM tool-turn loop and a timed SQLite poller that is never on the reaction path. Its status there is "Oracle → retire", retired at gate R16 (ADR 0016 §49, `R16_ORCHESTRATOR_RETIRED`).

So the proposal is: **do not port it.** Keep it untouched as the reference oracle, the old system new results are compared against, through R15. At R16 archive the repository. The resident AEGIS work in R8 replaces its job.

Cost of this choice: 9,207 lines of Rust stay alive until R16. They are never linked into Aienux or Omega.

### Step 3: aienos, in the order boot → kernel → store → crypto

Each part gets a C twin that passes the same tests as the Rust version before the Rust is removed.

**3.0 First, a small cleanup that is already unblocked:** stop the kernel re-exporting the Rust capability crate (`caps.rs`). Have it use the C authority in `native/capability/` instead. Then remove `aienos-capability` and `aienos-capability-ffi` (1,470 lines).

**3.1 boot (4,580 lines).** The UEFI loader. It uses the outside `uefi` crate, which is 197 vendored files across `uefi`, `uefi-raw`, and `uefi-macros`. The C twin needs its own UEFI definitions, written from the UEFI spec. Test: the existing `verify-efi` evidence check and the QEMU boot and rollback tests in `scripts/verify_all.sh`, run on both the Rust-built and C-built `.efi`.

**3.2 kernel (37,849 lines, minus store).** The big one. Port it module by module. Each module's existing unit tests and the `crates/aienos-kernel/tests/` files (NVMe write, completion, PRP, flush, and so on) become the twin's tests. The artifact loader's 1,615-line test file and the H01–H29 corpus are the admission check.

**3.3 store (3,487 lines in the kernel + 477-line store-tool).** System Store v1. Tests: `store_v1_golden_vectors.rs` and `store_v1_negative.rs`, plus the QEMU crash tests (`qemu_store_crash_test.sh`, `qemu_store_512b_crash_test.sh`). The C twin must read and write byte-identical stores. A store written by Rust must open in C and the other way round.

**3.4 crypto (922 lines).** AES, AES-GCM-SIV, POLYVAL, SHA-256. Test against the same known-answer vectors the Rust uses. Ed25519 is a separate question (see §6).

**A problem with this order.** Crypto is the bottom of the stack, and kernel and store sit on top of it. Porting the kernel before crypto means the C kernel has to call the Rust crypto across a C bridge for a while. The same happens with store if it goes after the kernel. That works, and it is what omega did with the capability authority, but it means temporary Rust-plus-C builds. The alternative is bottom-up (crypto → store → kernel → boot), which needs no bridges but leaves boot, the most visible part, for last. This is listed as an open choice in §6.

**The other nine aienos crates** are not in the order above:

| Crate | Lines | Proposed placement |
|---|---:|---|
| capability, capability-ffi | 1,470 | Removed in 3.0 (C twin already exists) |
| artifact | 2,505 | With crypto (3.4), since it is signing and verification |
| artifact-tool | 1,319 | With artifact |
| accel | 2,218 | With kernel (3.2); boot and kernel both link it |
| store-tool | 477 | With store (3.3) |
| evidence | 1,728 | With boot (3.1); it is the `.efi` checker |
| aegis, agent-state, cortex, c1-tree | 4,646 | **Not decided.** These are host-side crates, not linked into the kernel or boot. Some may be retired rather than ported, like aegis-runtime. See §6 |

---

## 4. CI rule: every C twin is built and tested

**Proposed rule:** a C twin does not count as existing until CI builds it and runs its tests on every change. The Rust version cannot be removed until the twin has been green in CI.

**Why this is needed now.** The one twin that already exists is not covered. aienos CI runs `scripts/verify_all.sh`, and that script never builds or tests `native/capability/`: it runs only `cargo` steps and QEMU. The C authority's 336 checks only run when someone types `make -C native/capability test` by hand, or indirectly when omega's Makefile builds the library for R7/R9. A twin nobody tests automatically can quietly drift away from the Rust it is meant to match.

**What the rule means in practice:**

1. Every C twin has a `make test` target, like `native/capability/Makefile` does.
2. `scripts/verify_all.sh` (aienos) and the omega CI workflow call every twin's `make test` and fail if any check fails.
3. While both versions exist, CI also runs a **differential test**: the same inputs go to Rust and to C, and the outputs must match. This is how the capability authority was proven (1M random operations). Golden vectors (fixed input/output files) are the minimum. Random differential runs are added where the input space is large (store, crypto, capability).
4. Twins for the AArch64 target (boot, kernel) must be cross-compiled on CI's x86 Ubuntu runners and run under the QEMU that CI already installs.
5. A PR that deletes Rust must link to the green CI run of the twin that replaces it.

---

## 5. What this plan does not change

- No Rust is deleted by this document.
- R15 and the Omega merge freeze are unaffected. None of these steps touch the R15 timing run.
- The earlier rule still holds: nothing is removed before rollback is proven (ADR 0016 §60).

---

## 6. Deferred / not decided

These are open. Each needs Drake's call or more measurement before work starts.

Status 2026-10-01 (Lane 33 reconciliation, recorded from merged code, not a new decision): item 1 was taken in practice as bottom-up (crypto `aien-dev/aienux#183`, Store `#190`/`#191`, then the C kernel `#194` to `#204`; C boot loader not started), under Drake's standing "go with the recommendation" rule. Item 2 was executed by `aien-dev/aienux#188` (`913b962`, own Ed25519 + SHA-512 in C, RFC 8032 vectors). Items 3 to 8 are unchanged. See `CURRENT_EXECUTION_PLAN.md` §2, Lane 33 addendum.

1. **Order inside aienos.** boot → kernel → store → crypto (as briefed, needs temporary C-calls-Rust bridges), or crypto → store → kernel → boot (bottom-up, no bridges, boot last).
2. **Ed25519 signatures.** Today they come from vendored outside code (`ed25519-dalek`). Writing my own Ed25519 in C is security-critical work that needs its own test plan: RFC 8032 vectors, plus a differential check against the current code.
3. **BLAKE3 in Crumb v1.** Either write BLAKE3 in C myself, or switch Crumb to a hash I already own (SHA-256 in aienos-crypto). Switching changes every digest, including `golden_registry_digest.txt`, so it is a format version bump, not a port.
4. **uuid v7 and JSON in Crumb v1.** Replace them with my own small encoders, or change the formats. Same trade-off as BLAKE3.
5. **UEFI in C versus assembly.** There is a parked proposal to write the boot program in AArch64 assembly through my own byte-writer. This plan assumes C for boot. Which one applies is not decided.
6. **aienos host crates** (aegis, agent-state, cortex, c1-tree, 4,646 lines): port or retire.
7. **The rest of sovereign-core** (about 82,000 lines after crumbs). No order is proposed. Much of it (spark-* services, aien-cli, inference ABI) may be retired rather than ported, and that needs a per-crate review first.
8. **The ~20 other aien-dev Rust repositories.** Not inventoried and not ordered.
9. **Python in omega CI receipt steps.** It conflicts with the no-outside-dependencies rule. Not Rust, but the same kind of cleanup, and not scheduled.
10. **When aienos `vendor/` can be deleted** (1,469 files). Only after the last Rust crate in aienos is gone.
11. **Where hand-written assembly goes.** Only where a measurement shows it beats C. No candidates are named yet.
