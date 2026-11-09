# Research Note: Hermes Agent and AIEN

Written 2026-10-18 for Drake's question: *does the open-source Hermes Agent hold
principles or mechanics that are unique and worth rewriting in our own language?*
Source of truth for every claim: the Hermes tree pinned below, read on disk (not
run). Claims are tagged [OBSERVED path] (read in the code), [DOCUMENTED path]
(read in Hermes's own developer guide) or [INFERRED]. Nothing here was executed.

## Source

| Item | Value |
|---|---|
| Repository | https://github.com/NousResearch/hermes-agent |
| Commit read | `548091836760a67e331b8f5643be8e5c08fae1e6` (2026-10-18) |
| Licence | MIT, Copyright (c) 2025 Nous Research. Rewrites are allowed; keep the credit line. |
| Language | Python (9,836 files, about 2.4 M lines, 1.47 M of them tests) |
| My copy | `~/workspace/investigations/2026-10-18-hermes-agent/upstream` on the Spark, with `PINS` and scout notes in `notes/` beside it |
| Prior mentions on my side | none outside the archived Odysseus fork (org-check receipt `org:8d23a45c210a`) |

Hermes is a general chat and messaging agent harness: a loop around a hosted or
local language model with tools, skills, memory files, a messaging gateway for
about 27 platforms, a cron scheduler and a session database. It is the kind of
thing AIEN's host runtime (sovereign core `aien` chat loop, aegis-runtime,
Aien) is also becoming, which is why the comparison is worth making.

## Method

Architecture and agent-loop guides read first-hand; the four large subsystems
(agent core; memory, skills, learning; tools, approvals, delegation; gateway,
cron, state) were each read by one scout against written questions, with
file:line citations, and the judgment below is the orchestrator's. My own side
was checked with `org-check` before any "I lack this" claim.

## 1. Context compression: the clearest lesson

Hermes keeps a conversation inside the model's window with two mechanisms
[DOCUMENTED website/docs/developer-guide/context-compression-and-caching.md,
micro-compaction.md; OBSERVED agent/context_compressor.py,
agent/conversation_compression.py].

**Batch compression** fires at 50 % of the window before a call (85 % between
gateway turns). It flushes memory to disk first, keeps the last 20 messages
verbatim, never splits a tool call from its result, and writes a structured
summary (goal, constraints, progress, decisions, files, next steps). Each
compression starts a child session lineage.

**Micro-compaction** is the part I do not have. It is opt-in in Hermes (off by
default, because each pass breaks the prompt-cache prefix). When on, after every normal turn it
absorbs exactly one *exchange* (one assistant turn with its tool results) into
a single rolling summary. Properties the code enforces:

- The user's own messages are never summarized. Only the agent's derived
  material (what it read, ran, saw) is compacted, because intent cannot be
  rebuilt from the work that followed it.
- Cost per turn is bounded: one exchange, one small summarizer call.
- The transcript is the source of truth for the cursor: a resumed process
  finds the last summary marker and continues after it, so nothing is
  summarized twice.
- Only the newest summary marker is kept; when the summary grows past 2,000
  tokens the next pass re-summarizes the summary itself ("defrag") without
  touching messages.
- The database step is an atomic archive-and-insert, so a resumed session never
  loads both the summary and the rows it replaced.
- A failing exchange is retried on later turns and skipped after three
  failures, so one bad exchange cannot stall every turn.

**Token accounting** is anchored on evidence, not estimates [DOCUMENTED
context-compression-and-caching.md "Token accounting"; OBSERVED
agent/usage_anchor.py]: the provider's last reported prompt and completion
counts, keyed by a content fingerprint and persisted on the session row, are the
truth; local estimates cover only the messages appended since. An estimate over
threshold, even one above the whole window, is not treated as proof that a
request will fail; the gate waits one request for provider evidence. Image
token cost is learned per model from the provider's reported usage, not from a
vendor formula.

**Failure handling** is a persisted cooldown ladder (60 s, 300 s, 900 s) per
session, with a deterministic fallback summary route when the summarizer stalls
twice, and commits through a lease, fence and watermark so two compactions
cannot interleave.

**What I have today.** The sovereign core already has a conversation compactor
(`crates/aien-cli/src/compaction.rs`, issue 397 there): tool-aware groups,
unsafe-boundary refusal, and durable originals with digests written before the
list changes, with replay. Hermes does not have that last property. I lack:
the one-exchange-per-turn bounded pass, the never-summarize-the-user rule, the
transcript-recovered cursor, the rolling summary with defrag, the atomic store
swap, and evidence-anchored token accounting. (org-check receipt
`org:461d52d75b01`.)

## 2. Memory and skills: small, plain, and written by the agent itself

Findings from the scout note `notes/scout-B-memory-skills-learning.md`.

**Memory** is two plain-text files with hard character caps, MEMORY.md at
2,200 and USER.md at 1,375 characters [OBSERVED tools/memory_tool_store.py,
agent/memory_manager.py]. A full store makes the write fail with a listing of
current entries, so the model must free space in the same batch. The prompt
snapshot of memory is frozen at session start; writes persist at once but are
visible only after the next rebuild. There is no vector store in the core.
External memory providers plug in behind one interface [OBSERVED
agent/memory_provider.py]; two adapters are in-tree. External recall is not put
in the system prompt: it is appended to the current user message as a fenced
"reference data" block, and the harness prints a deterministic "recalled N
memories" line so the model cannot silently ignore it.

**Skills** are folders with a `SKILL.md` plus optional references, templates
and scripts. The system prompt carries only an index: name and a 60-character
description, enforced by tests; the model loads a skill by calling a view tool
and is told to load anything even partly relevant. There is no matcher and no
embedding [OBSERVED tools/skills_tool.py, agent/prompt_builder.py].

**The agent writes its own skills** ("the agent that grows with you")
[OBSERVED agent/background_review.py, agent/learn_prompt.py,
tools/skill_manager_tool.py, tools/skill_ledger.py]:

- After a turn, and on two independent counters (every 10 user turns for memory,
  every 10 tool iterations for skills), a forked copy of the agent reviews the
  conversation. The fork runs on the same prompt cache with a dispatch-side
  tool whitelist, so the tool schema bytes stay identical.
- The review prompt carries editorial policy: lessons, not logs; class-level
  skills over one-off recipes; never record an unresolved failure or a negative
  claim about a tool.
- Read-before-write is enforced in code: the fork must view the exact file
  within the same review before patching it.
- Unattended forks may only add to memory; patch and remove are staged for a
  person's approval.
- Every skill mutation by any actor goes to a JSONL ledger with
  content-addressed before and after blobs and single-edit rollback that fails
  closed.
- Skill telemetry (views, uses, patches) lives in a sidecar file and drives an
  inactivity state machine: active, stale after 14 days, archived after 30,
  with exemptions for pinned and cron-referenced skills.

**What I have today.** Cortex (omega) is an append-only lessons and sources
memory with recall; the Skill Router and Capability Graph are host-side omega
modules; skills on the Spark are Claude Code skills. I have no mechanism by
which the agent itself distils a run into a skill under an editorial policy,
no skill ledger with rollback, and no use-driven skill ageing.

## 3. The turn loop: persist before acting, plan the tool batch

Findings from `notes/scout-A-agent-core.md` [OBSERVED agent/conversation_loop.py,
agent/turn_tool_round.py, agent/turn_context.py, agent/tool_executor.py,
tools/tool_dispatch_helpers.py, agent/turn_retry_state.py,
agent/turn_truncation.py, tools/budget_config.py].

- **Persist before acting.** The assistant message that requests tools is
  written durably to the session database before any tool runs; if that write
  fails the turn ends. The exact wire bytes of an injected user message are
  kept as a sidecar so later turns replay byte-identical prompts.
- **Tool batch planning.** A batch of tool calls is planned into ordered
  parallel and sequential segments using path-overlap reservations between
  readers and writers, with a start-order gate and timeout. Results spill to
  disk under three budgets (per result, per turn, window-scaled), largest
  first.
- **Recovery that cannot loop.** About 28 failure reasons are classified; each
  recovery is a one-shot flag per attempt. A tool call truncated by the output
  cap is retried with an exponentially raised cap and is never executed with
  incomplete arguments. The credential pool is tried before the fallback model
  chain.
- **Cache-stable extras.** Mixture-of-agents guidance and mid-session "skills
  changed" notes travel as trailing user messages, never as prompt rebuilds;
  many comments name prompt-cache stability as the reason.
- **Trajectories** are written as ShareGPT-style JSONL with tool-call tags and
  a think block per assistant turn; an offline tool replaces the middle of a
  trajectory with one summary turn. Whether any released model was trained on
  this data is UNKNOWN from the tree.

**What I have today.** The sovereign core chat loop has hooks and the
compactor; it has no persist-before-act rule, no batch planner with path
reservations, and no one-shot recovery ledger (not checked by org-check;
stated from the sc#397 inventory, which lists the loop's entry points).

## 4. Gateway, cron and state: guarantees chosen per path and written down

Findings from `notes/scout-D-gateway-cron-state.md` [OBSERVED
gateway/delivery_ledger.py, gateway/session.py, cron/scheduler_tick.py,
cron/occurrences.py, cron/scheduler_authority.py, cron/scheduler_liveness.py,
cron/quota_hold.py, hermes_state.py, hermes_state_repair.py, pm/environments.py,
hermes_platform/].

- **Delivery guarantees are chosen per path and stated in code.** Gateway
  replies are at-least-once: the reply row is written to a ledger before the
  send, and a crash-recovered send carries a visible "Recovered reply" marker.
  Cron sends are at-most-once: any uncertainty is recorded as `unknown` and
  never replayed. The obligation id is a content hash of session key, message
  reference and reply text, so an identical re-record collapses to one row.
  Owner stamps are pid plus process start time, compare-and-set, to survive
  pid reuse.
- **Cron fires at most once.** The schedule is advanced before the job runs;
  if the advance cannot be persisted the due jobs are skipped on purpose. Each
  fire is identified by its exact scheduled instant. Jobs run as gateway
  sessions through an on-disk admission journal; an unclear admission pauses
  the job, and only the matching verified receipt lifts that pause. Liveness
  is silence since the last progress stamp, not run length. A provider quota
  hold parks the next run at the usage-window end and coalesces missed
  occurrences.
- **Session admission** is a durable per-session queue (32 rows) with a
  runtime epoch and generation fences; rows started by an older epoch become
  `unknown` and need an operator's word before the queue resumes.
- **State store.** One SQLite file per profile; writes retry the whole
  transaction with jitter; full-text search with no embeddings; index
  corruption degrades to plain scans rather than blocking writes; offline
  repair works on a scratch copy with a persistent ledger of strategies tried.
- **Environments as immutable generations.** The package manager builds a new
  environment beside the old one; a selection record written last, after a
  filesystem sync, is the completion marker; leases block deletion of a
  generation in use. Binaries are pinned by URL and sha256 only.
- **Machine facts take no environment-variable input**; hardware recognisers
  are table-driven from OS-reported identity (the GB10 is in that table).

**What I have today.** aegis-runtime has a WebSocket gateway and a heartbeat
scheduler but no delivery ledger and no at-most-once cron discipline (its
README and source list neither). The hive's forge queue and lanes ledger are
shell-level. Synapse has revisions and recovery for changesets, not for
message delivery. The Aienux continuity commit path already does
advance-before-act for its own store (ADR 0016).

## 5. Tools, approvals, delegation, checkpoints

Findings from `notes/scout-C-tools-approvals-delegation.md` [OBSERVED
tools/approval_floors.py, tools/approval.py, tools/approval_smart.py,
tools/delegate_tool_registry.py, tools/checkpoint_manager.py,
tools/code_kernel.py, tools/budget_config.py, agent/tool_executor.py].

- **Approval floors above every mode.** Four floors are checked first and
  cannot be bypassed by "yolo" or "off": a hardline command list, deletion of
  the runtime itself, `sudo` with a piped password, and the operator's own
  deny patterns, which outrank even the container shortcut. Only after the
  floors do mode, permanent allowlist, presence of a person, about 102
  dangerous-command patterns, and the human decision run. "Smart" mode asks a
  guardian model for approve, deny or escalate behind a circuit breaker;
  unattended modes default to deny.
- **Delegation** runs children as in-process threads on a daemon pool, with
  background children recorded in a durable ledger and recovered after a
  restart. The docs and code disagree on defaults (docs: depth 2, concurrency
  3, 250 iterations; code: depth 1, 10, 50).
- **Checkpoints** use one shared bare git store with one snapshot per
  directory per turn, plus a ledger of the agent's own writes, so a rollback
  restores what the agent changed and leaves the operator's own edits alone.
- **Code execution** is a persistent per-conversation kernel behind a
  token-checked socket; each cell receives its own revocable tool authority;
  a timeout kills the kernel and discards its state on purpose.
- **Budgets** are iterations (consume, refund, one grace call) and result
  sizes (100k per result, 200k per turn, 50k for MCP, spilled to files, head
  40 % and tail 60 % kept). No hard cost or token budget was found.

**What I have today.** Capability-bounded, receipt-producing effects are
Omega doctrine (SMART is not TRUSTED), ARGUS is the defensive plane, and
INTERPLANE holds an action for a person when untrusted content is in view.
What I lack is the ordering rule as code (floors first, then modes, with the
operator's deny list outranking everything) and a file rollback that keeps
the agent's writes apart from the operator's.

## 6. Judgment: what is worth rewriting, in which language, and where

The principles below are the ones that are both unusual in Hermes and absent
on my side. Each becomes one issue; the issue carries the credit line.

| # | Principle (Hermes mechanic) | Why it is worth making mine | Lands in |
|---|---|---|---|
| 1 | Bounded micro-compaction: never summarize the operator; one exchange per turn; transcript-recovered cursor; rolling summary with defrag; atomic store swap; evidence-anchored token accounting | Direct fit with "no guessing": provider usage is a receipt, an estimate is not. Extends sc#397 instead of replacing it | aien-sovereign-core (`aien` chat loop) |
| 2 | Persist-before-act turn discipline; byte-identical replay sidecar; one-shot recovery flags; never run a truncated tool call | Same idea as Aienux continuity commits (advance the record, then act), applied to the chat loop | aien-sovereign-core |
| 3 | Tool batch planning with reader/writer path reservations; result spill under three budgets | My loop runs tools one at a time; this is the safe form of parallelism | aien-sovereign-core |
| 4 | Agent-written skills under an editorial policy: forked reviewer, lessons not logs, read-before-write enforced, unattended is add-only, content-addressed skill ledger with rollback, use-driven ageing | My Cortex records lessons but nothing distils runs into skills; the ledger is content-addressed, which is Omega's own idea | omega (Cortex, Skill Router) |
| 5 | Delivery and scheduling guarantees stated per path: at-least-once reply ledger with content-hash obligation ids and a visible duplicate marker; at-most-once cron (advance before run, pause on uncertainty, liveness by silence since progress, pid plus start-time owner stamps, epoch fences) | Aien's heartbeat and the hive's queue have no stated guarantee today; this is how "it ran once" becomes provable | aegis-runtime (gateway, heartbeat) |
| 6 | Approval floors ordered above every mode; agent-write ledger so rollback spares the operator's edits | Turns ARGUS and capability doctrine into one ordering rule the loop cannot skip | aien-sovereign-core (with aienos ARGUS as reviewer) |

**Language.** Rust now, Omega as the destination (ADR 0024). Omega has no
general compiler today (omega README, 2026-10-03), so "an Omega" is not an
option for working code this month. The rule for each rewrite: the pure part
(summary folding, token accounting, the delivery state machine, the skill
ledger) is written as a content-addressed, effect-free module with a stated
interface, so it can be carried into Omega as a semantic identity later; only
the edges (SQLite, sockets, files) stay host Rust.

**Not worth rewriting** (ordinary, or already mine): the three API modes and
provider adapters, the 27 messaging platforms, the Python package manager,
the browser and computer-use stacks, the TUI, and the mixture-of-agents
provider. The environment-generation idea in the package manager and the
table-driven machine facts are good habits, noted here, not issues.

**Licence and credit.** MIT allows rewriting. No Hermes code is to be copied;
mechanisms are re-implemented from the description above and from reading.
Each issue and each resulting module header names Hermes Agent, Nous Research,
the MIT licence and the commit read. If any text is carried over verbatim
(for example a prompt rule), the MIT notice goes into that repository's
NOTICE file.

## 7. If I move onto Hermes as the day-to-day harness

Drake raised a transfer to Hermes on 2026-10-18. What the tree says a transfer
needs [DOCUMENTED README.md, website/docs/user-guide/which-file-does-what.md;
OBSERVED agent/prompt_builder.py, tools/memory_tool_store.py]:

| My asset today | Hermes equivalent | Caveat |
|---|---|---|
| `~/.claude/CLAUDE.md`, `AGENTS.md` | `AGENTS.md` and project files in the context tier; `SOUL.md` for identity | project files are capped per file; order is SOUL, guidance, pinned skills, then project files |
| Memory directory (over 100 files) | `MEMORY.md` (2,200 characters) and `USER.md` (1,375) | will not fit; needs an external memory provider, which is where my Cortex could plug in |
| Claude Code skills | `skills/<name>/SKILL.md` with a 60-character description | the model, not a matcher, chooses skills from the index |
| Hooks (manual-guard, docs-guard, chat-size) | gateway hooks and observer hooks, middleware | hooks are gateway-side; CLI-side enforcement is thinner |
| Subagents | the delegate tool (in-process threads) | defaults differ between docs and code |
| MCP servers | `optional-mcps` and the MCP tool | OAuth sessions handled in the TUI gateway |
| Cron jobs on the Spark | Hermes cron (at-most-once, see section 4) | jobs run as gateway sessions |
| Python rule | Hermes is Python end to end | it would be an outside tool I use, not part of the trusted base |

## 8. Limits of this note

One commit read on one day. Scouts did not read: the micro-compaction body
itself (documentation plus gating code only), the conversation-turn undo code,
the docker egress and ownership modules, 26 of 27 platform adapters, the full
scheduler, and the package-manager update path. No Hermes code was executed,
so timings, cache savings and the vendor's cost claims are unverified. Whether
Hermes's self-review improves outcomes is UNKNOWN from the tree: its evals do
not test memory or skill quality.
