# Crumb Protocol RFC-0002: Common Coordination Plane and Continuation Crumbs

**Status:** Proposed, 2026-10-04. Decided by the operator, Drake Stapleton, through his approved design of 2026-10-04 (pasted; the paste is the decision, no separate ratification). Source of record: `~/handoffs/rfc-0002/master-spec-drake-2026-10-04.md` on the Spark.
**Extends:** RFC-0001 v1.0.0 (`aien-spark/crumb-spec` `SPEC.md`, `ROLES.md`, frozen at `10b8251`). RFC-0001 is not changed; this document adds a storage scope, a mutation discipline, two commands and one new object. Protocol version becomes **1.1.0**.
**Related:** `docs/CRUMB_PROTOCOL.md` (how RFC-0001 is used here), ARCH-0029 (Verified Crumbs: untouched), ARCH-0028 (receipts).
**Implementation:** `tools/crumb/crumb.c` (C11/POSIX, no dependencies), tests in `tools/crumb/test.sh`. Code is the truth; where this text and the code differ, the difference is a bug in one of them and is named, not papered over.

## In plain words (read this first)

Git remembers what happened. Crumbs explain what it meant. Today every checkout folder of a repository keeps its own private notebook of "who is working where" (`.crumb.local`), so two agents working in two folders of the same repository cannot see each other. RFC-0002 moves that notebook to the one place all those folders already share (the repository's common git directory), makes writing to it safe when two agents write at the same moment, and adds two things on top: a way to ask Crumb what an unfamiliar file is for (`crumb explain`), and a compact record of where a session stopped so a fresh agent can continue without the old conversation (a Continuation Crumb).

## 0. Current-state audit (2026-10-04, against aien-architecture `origin/main` `0128197`)

| Item | Finding |
|---|---|
| Standard | RFC-0001 v1.0.0 in archived `crumb-spec` (`SPEC.md`, `ROLES.md`, `schema/crumb.schema.json`, `schema/crumb-local.schema.json`). `ROLES.md` section 3 already defines a Subagent Handoff Protocol (whisper assignments, child registers scent, completion whisper, parent verifies). |
| Live tool | `tools/crumb/crumb.c`, 941 lines, commands seed/backfill/create/claim/update/whisper/close/sniff/list/validate. Writes `.crumb.local` **next to each `.crumb`** (line ~311) with tmp + `rename()` (line ~259). No OS lock. Targets are stored as given (basenames or relative strings), not normalized to repository-relative paths. Scents carry agent id, focus, TTL; locks carry holder, target, intent, TTL. No worktree, branch or HEAD metadata. |
| Scope bug | Linked worktrees do not share `.crumb.local`. Observed in this very lane: a claim made in `~/workspace/hive-worktrees/rfc-0002-docs/docs` is invisible from `~/workspace/aien-architecture/docs`. |
| Tests | `tools/crumb/test.sh`: seed idempotence, gitignore, legacy `.crumb` untouched, validate, hand edits survive reseed, claim/second-claim-blocked (exit 2)/different target, in ONE scratch repo. No worktree, concurrency, TTL, normalization or legacy-import tests. |
| Rust | `crumb-spec/src/{lib.rs,ledger.rs}` (archived) and the older `spark-crumbs` crate write a different shape; `docs/CRUMB_PROTOCOL.md` already rules that RFC-0001 wins and legacy files are left alone. Neither is on the agents' path; the C tool is. |
| Handoff today | Free-form Markdown in `~/handoffs/`, plus (since 2026-10-04) the `checkpoint` skill with `cc.sh` writing `~/handoffs/checkpoints/<id>.json` and a crumb whisper pointer. Works, but lives outside the repository's coordination plane. |
| Verified Crumbs | ARCH-0029 defines `VerifiedCrumbV1` for dependency resolution; nothing implemented. Not touched by this RFC. |

Discrepancy named: `docs/CRUMB_PROTOCOL.md` says agents "coordinate through crumbs" as if that were repository-wide; the implementation is worktree-local. The implementation changes; the sentence then becomes true.

## 1. Versioning decision

A new RFC (RFC-0002) rather than editing RFC-0001, because RFC-0001 is frozen in an archived repository and other documents cite it by number. RFC-0002 is additive: every RFC-0001 field keeps its meaning; what changes is **where** `active_scents`, `locks`, `whispers` and `history` are stored and **how** they are written. A tool that implements RFC-0002 reports protocol version `1.1.0`. A directory's committed `.crumb` is unchanged and still validates against `crumb.schema.json` 1.0.0.

## 2. Common Coordination Plane

### 2.1 Coordination root resolution (deterministic)
1. `CRUMB_COORD_ROOT` environment variable, if set (escape hatch for unusual layouts and tests).
2. `git config crumb.coordinationRoot`, if set in the repository.
3. `git rev-parse --git-common-dir` + `/crumb/v1`.
4. Otherwise **fail clearly** for shared operations: `no repository context: run inside a git checkout or set CRUMB_COORD_ROOT`. The tool never invents global state under a home directory. (Transition only: a directory outside any git repository may keep today's `.crumb.local` behaviour; the sniff output must say `shared coordination: none`.)

### 2.2 Layout (semantic requirement; physical shape may be simplified by the implementation)
```
<coordination root>/
  dirs/<repository-relative directory>.json   one record per directory, same fields as RFC-0001 .crumb.local
  agents/<agent-id>.json                      presence and git context of each live agent
  continuations/<continuation-id>.json        Continuation Crumbs (section 5)
  ledger/                                     append-only action vectors beyond the 20-entry rolling history
  .lock                                       transaction lock file (section 3)
```
The repository root directory is keyed `_root`.

### 2.3 Repository-relative identity
A resource is identified by **repository identity + repository-relative path**. `/wt-a/native/kernel/core/infer.c` and `/wt-b/native/kernel/core/infer.c` are one resource `native/kernel/core/infer.c`. The implementation normalizes every `dir` and `target` argument through `git rev-parse --show-toplevel` of the worktree it is invoked in, resolves `.`/`..`/symlinks, and stores the relative form. Branch, worktree path, HEAD and base commit are **holder metadata**, never part of the identity. There is no per-branch namespace; a future `--allow-parallel-branch` flag may relax this explicitly, the safe behaviour is the default.

### 2.4 Lock semantics
A lock on a repository-relative target is visible from every linked worktree. A second `claim` on a held, unexpired target returns exit code 2 and prints the holder, its worktree, branch and intent. Git permitting conflicting edits is not a reason to weaken this; surfacing that overlap is the point of Crumb.

### 2.5 Holder metadata
Scents and locks carry: `agent_id` (stable session id supplied by the caller; never a PID alone), `worktree`, `branch`, `head`, `base` when cheaply known (`merge-base` with `origin/main`), `focus`/`intent`, `acquired_at`/`updated_at`, `ttl_seconds`.

### 2.6 Sniff output (shared view)
```
CRUMB <repo-relative dir>
shared coordination: ACTIVE   root: <coordination root>
ACTIVE AGENTS   id, branch, focus, heartbeat age
LOCKS           target, holder, branch, intent, expires in
OTHER WORKTREES path, branch, agent if any, conflicts with this directory or none
WHISPERS        priority, from, to, age, text
CONTINUATIONS   newest continuation ids whose scope touches this directory (section 5)
```
followed by the RFC-0001 `.crumb` summary (purpose, invariants, exports, related).

## 3. Mutation discipline (transaction safety)

tmp + `rename()` prevents torn files but not lost updates (A and B both read version 10, both write version 11, one lock vanishes). Every mutation of the shared store runs:
```
acquire fcntl(F_SETLKW, F_WRLCK) on <root>/.lock
read current record(s) -> prune expired scents and locks -> validate -> apply mutation
write temporary file -> fsync(tmp) -> rename(tmp, final) -> fsync(directory) -> release the lock
```
The **transaction lock** is an OS lock held for milliseconds and protects the database. The **Crumb resource lock** is the advisory claim in `locks[]`, held for minutes or hours and meaning "an agent owns this target". They are different things and are never confused in code or output.

### 3.1 Store identity and hostile store files (synapse-coord compatibility, [#234](https://github.com/aien-spark/aien-architecture/issues/234))
Two agents pointed at two different coordination roots each believe they hold the same lock; nothing in section 2.1 stops that. A coordination root therefore carries a **store identity**, byte-compatible with the Rust `synapse-coord` crate ([synapse#15](https://github.com/aien-spark/synapse/issues/15)), and every reader refuses store files it cannot read safely ([synapse#58](https://github.com/aien-spark/synapse/issues/58)).

- **Marker.** `<coordination root>/STORE_ID` holds exactly `crumb-coord-store-id/1 <32 lowercase hex>\n` (56 bytes), drawn from `/dev/urandom` and written under the transaction lock (tmp, `fsync`, `link(2)`, directory `fsync`), so two first writers cannot both win. Either tool may create it; both read it the same way, and neither rewrites an existing marker.
- **Registration.** The expected id is `CRUMB_EXPECT_STORE_ID` when set and non-empty, else `git config crumb.storeId` (one value for every linked worktree of the repository). `crumb store-id [dir]` prints the store's id and is the onboarding step: `git config crumb.storeId "$(crumb store-id .)"`. The Rust side takes the same id as `--expect-store-id`.
- **Three modes.**
  1. *Unregistered (compatibility, the default).* No expected id. Every command works as before; the first mutation creates the marker, and while a marker exists but no id is registered each coordination command prints one stderr line, `STORE_UNREGISTERED (dry run): ... register it: git config crumb.storeId <id>`. Standard output and every `dirs/` and `agents/` record are byte-identical to the pre-#234 tool.
  2. *Registered.* An expected id is set. Before any read or write, and again under the transaction lock before a mutation, the root's marker must match. It never creates a marker.
  3. *Strict.* `crumb --strict <command>` or `CRUMB_STRICT_STORE_ID=1` additionally refuses an unregistered root before creating anything (`store-id` stays allowed, for onboarding).
- **Migration.** Run unregistered and watch for the dry-run line; register each repository with `git config crumb.storeId`; turn on strict mode for onboarded swarm agents so a misconfigured root fails closed. The legacy `.crumb.local` path outside a repository (section 4) is unaffected.
- **Exit codes.** `2` is unchanged (held by another agent). `3` is a store identity refusal, named `STORE_ID_MISMATCH` (the root is another store: split coordination roots), `STORE_ID_MISSING` (an id is expected but the root has no marker), `STORE_ID_UNREADABLE`, `STORE_ID_CONFIG_INVALID` (the configured id is not 32 lowercase hex) or `STORE_UNREGISTERED` (strict mode). `4` is `REFUSED_RECORD`: a store file is a FIFO, socket, device, directory or symbolic link, sits under a symlinked directory, or is larger than the cap. The message names the file and says to fix or move it aside; the file is never replaced.
- **Reads and caps.** Every store file `crumb` reads (records, continuations, `STORE_ID`; `.lock` is opened the same way but never read) is opened `O_NOFOLLOW | O_NONBLOCK` after an `lstat`, checked again with `fstat`, and read up to a cap: 1 MiB (1048576 bytes) for a record, 4096 bytes for the marker. A record over 1 MiB is refused on write too, so the tool never writes what it would refuse to read. Record walks do not descend into symlinked directories.
- **Independence from the mission board.** These ids name one repository's coordination store. A swarm mission board ([synapse#83](https://github.com/aien-spark/synapse/issues/83)) has its own root and is not one of these stores; registering a repository never registers, joins or reads a board, and a board never satisfies `crumb.storeId`.

## 4. Legacy `.crumb.local` (RFC-0001 physical form)

- New writes go only to the shared store (inside a repository).
- Reads merge: shared store first, then any `.crumb.local` present in the invoking worktree; an unexpired legacy scent or lock is shown with `legacy:` and an `imported_from: <worktree path>` provenance. Legacy state never overrides a newer shared record for the same key.
- `crumb seed` / first shared write in a directory imports an existing `.crumb.local` once (provenance kept) and leaves the file on disk; nothing is deleted.
- `.gitignore` handling for `.crumb.local` stays, for the transition and for non-repository directories.
- Scope: `.crumb.local` and the shared store are single-machine scratch state, not a coordination channel between agents; cross-agent claims go through the issue tracker and draft pull requests (see Scope in `docs/CRUMB_PROTOCOL.md`).

## 5. Continuation Crumb (`ContinuationCrumbV1`)

Purpose: checkpoint the meaningful **state of work** when a session ends so another agent, in any worktree, can continue. It is not a transcript, not a summary of the chat, and not an oracle. Schema: `docs/crumbs/continuation-crumb.schema.json`. Reference implementation today: the `checkpoint` skill (`cc.sh`), whose record is this schema's `acr_version: 1` precursor; it moves into `<root>/continuations/` as `crumb checkpoint` / `crumb resume` (section 7).

### 5.1 Shape (smallest stable set)
```
identity        id, version, created_at, created_by (agent id), reason, supersedes
repository      remote, branch, base, head, worktree (one entry per repository in scope)
mission         objective, milestone, definition_of_done[] (verbatim; may not be softened at checkpoint time)
state[]         {tag: PROVEN|PARTIAL|BLOCKED|ASSUMED|OPEN, claim, evidence[], blocker, note}
evidence        commits[], prs[], tests[] {name, command, result, where}, receipts[], golden_values[] {name, value, source}
execution       current, next[] {id, task, depends_on[], gate}, backlog[]
coordination    scope[] (.crumb paths this record is about), owned[], other_owned[] {who, paths}, do_not_touch[]
operator        approval_required[], hardware_rules[], destructive_rules[], standing_preferences[]
resume          validate_first[], first_action, bootstrap (<= 700 chars)
revalidation    status UNVERIFIED|NEEDS_REVIEW|VERIFIED, checked_at, checked_by, findings[] {field, result: CONFIRMED|STALE|SUPERSEDED|UNKNOWN, note}
```
Rules enforced by the tool, not by goodwill: a `PROVEN` item without at least one evidence reference is rejected; a `BLOCKED` item without a named blocker is rejected; `definition_of_done` must be non-empty; the record is rejected above a size budget (~4000 tokens of JSON) because size means history crept in.

### 5.2 Referential, not duplicative
Evidence entries are references the next agent follows: `commit:<sha>`, `pr:<repo>#<n>`, `receipt:<path>`, `test:<name>`, `crumb:<dir>/.crumb`. Nothing Git already knows (diffs, authorship, chronology) is copied in. The `scope[]` list names the committed `.crumb` files that describe the code involved; `crumb explain` and `crumb sniff` surface a continuation whenever its scope touches the directory being asked about.

### 5.3 Epistemic boundary
`PROVEN` means "a receipt exists at this reference against this commit", not "the previous agent was confident". Where a receipt is an `EvidenceReceiptV1` (ARCH-0028) or, in future, a `VerifiedCrumbV1` (ARCH-0029), the reference points at it; this RFC does not redefine either object.

## 6. Lifecycle additions

Normal work (RFC-0001): SNIFF -> LEASE -> EXECUTE -> WHISPER.
Session end: SNIFF -> **QUIESCE** (no new branches, decisions or workers) -> **CHECKPOINT** (write the record from the machine state, not from memory) -> **VERIFY** (`check` passes) -> **WHISPER** (high-priority pointer `Session continuing at <id>` in the root and each scope directory) -> **RELEASE** (close every held lock).
Fresh session: SNIFF -> **RESOLVE CONTINUATION** (newest id from the whisper or `continuations/LATEST`) -> **REVALIDATE** (section 6.1) -> LEASE (re-claim `owned[]`; exit 2 means someone else holds it: stop) -> RESUME (`first_action`).

### 6.1 Revalidation (mandatory)
The tool compares each recorded repository entry with the live repository: fetch; HEAD moved? pinned commit still an ancestor of `origin/main` (else SUPERSEDED)? evidence commits present? receipt files present? who holds locks now? It writes machine findings into `revalidation.findings`. The agent then does what the tool cannot: re-check the top blocker at its implementation site, re-read the cheapest critical receipt, and record a verdict per stale field. Nothing in the record is presented as current until this has run.

## 7. Commands (CLI stays small)

Existing: `sniff`, `claim`, `update`, `whisper`, `close`, `list`, `seed`, `backfill`, `create`, `validate` (now operating on the shared store).
New:
- `crumb explain <file-or-dir>`: assembles, in this order and nothing more: nearest `.crumb` (purpose, layer, invariants, exports, related); inherited invariants from parent `.crumb` files up to the root; shared coordination for that directory (agents, locks, whispers); the last 10 commits touching the path (`git log --oneline -- <path>`) plus any commit the `.crumb` or a continuation names as significant; evidence references found in `.crumb` `extensions` and in continuations whose scope touches the path; the newest continuation touching the path with its `state` lines. Output is plain text sections of bounded size (defaults: 10 commits, 5 whispers, 1 continuation) so an LLM can read it without a large payload. Answers: what is this, why, what rules, how did it get here, what is proven, who is here now, where did prior work stop.
- `crumb checkpoint <agent> [--reason R]`: creates `<root>/continuations/<id>.json` from the template with repository entries filled from git, prints the path for the agent to complete, then `crumb checkpoint --seal <id>` runs the checks, stamps `sealed_at` and sha256, writes the Markdown rendering, updates `LATEST`, leaves the whisper.
- `crumb resume <id>`: prints the record, runs revalidation, records findings, prints the bootstrap text.

Why checkpoint/resume may start outside the C binary: the logic exists today as `cc.sh` (POSIX sh + `jq`) and is being used; porting it to C is mechanical and planned, but landing the shared store first keeps the C change reviewable. Until the port, `cc.sh` resolves its store exactly as section 2.1 does, so records already land in `<root>/continuations/`. That is the precise, implementation-ready continuation for deliverable 14/15, not a TODO.

## 8. Scope boundary

This RFC closes the gap for **all linked worktrees of one repository on one filesystem**. Independent clones (another machine, CI, another Spark node) do not share a common git directory and are out of scope. The store is reached through one small internal interface (`store_read`, `store_write`, `store_lock`, `store_root`) so a later `DaemonStore` or distributed backend can replace `GitCommonStore` without touching command code. No transport is chosen now.

## 9. Tests (the feature is not done until these run)

| # | Test | Where | Result (2026-10-04) |
|---|---|---|---|
| T1 | Cross-worktree visibility: A claims `src/runtime.c`, B's sniff from worktree B shows it | `tools/crumb/test.sh` | PASS (`make -C tools/crumb test`, 0 FAIL) |
| T2 | Cross-worktree conflict: B's claim of the same target exits 2 | same | PASS (`make -C tools/crumb test`, 0 FAIL) |
| T3 | Release: A closes, B's claim succeeds | same | PASS (`make -C tools/crumb test`, 0 FAIL) |
| T4 | Independent targets: both claims survive | same | PASS (`make -C tools/crumb test`, 0 FAIL) |
| T5 | Concurrent mutation: 8 parallel distinct claims all survive; 8 same-target claims yield exactly one success | same | PASS (`make -C tools/crumb test`, 0 FAIL) |
| T6 | TTL/crash: expired lock pruned, reclaimable | same | PASS (`make -C tools/crumb test`, 0 FAIL) |
| T7 | Path normalization: two absolute worktree paths -> one lock identity | same | PASS (`make -C tools/crumb test`, 0 FAIL) |
| T8 | Legacy `.crumb.local` read/import with provenance, never overriding newer shared state | same | PASS (`make -C tools/crumb test`, 0 FAIL) |
| T9 | Continuation revalidation: checkpoint at C, advance the repo, resume reports STALE/SUPERSEDED and status NEEDS_REVIEW | `tools/crumb/test-continuation.sh` | PASS (8 checks; STALE repo HEAD + NEEDS_REVIEW; SKIP prints NOT_RUN where jq or cc.sh is absent) |
| E1 | `crumb explain`: every section header, nearest `.crumb`, commits, locks and whispers, continuation surfaced by `owned_paths` and by `scope`, unrelated continuation ignored, missing path fails | `tools/crumb/test.sh` | PASS (15 checks) |

Results are reported PASS / FAIL / NOT_RUN per test in the merging PR; nothing unrun is called PASS.

## 10. Agent bootstrap rule (global, one paragraph)

> Before modifying an unfamiliar repository path, inspect the applicable Crumb (`crumb explain <path>`, then `crumb sniff`). Respect its invariants and shared locks. Follow related Crumbs, Git history, evidence and active continuation state until the purpose of the code is understood. Do not rely on undocumented assumptions from previous sessions. Load context on demand; do not expect the whole architecture in your window up front.

Workflow detail: `docs/crumbs/AGENT_WORKFLOW.md`.

## 11. Principle (keep the layers apart)

Git is the historical substrate. `.crumb` files are the semantic graph. Receipts are the proof layer. Continuation Crumbs are resumable execution state. The shared coordination plane is the live concurrency layer. None of them takes over the job of another: no history copied into crumbs, no claims accepted without receipts, no coordination state treated as architecture, no continuation treated as truth before revalidation.
