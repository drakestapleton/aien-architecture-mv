# Spark test schedule and own-model recovery (DRA-118)

Status: **PROPOSED** operations runbook, written 2026-11-06 for [DRA-118](https://linear.app/drake-stapleton/issue/DRA-118).
It is a component runbook for the one shared Spark, not a cross-project plan; sequence authority stays
with `CURRENT_EXECUTION_PLAN.md`. It schedules tests and states the :18091 recovery contract. It deploys
nothing, binds no port and grants no hardware, signing or reset authority.

## 1. What changed and what this replaces

| Old instruction | Now | Source |
|---|---|---|
| Saturday-evening restore of the 35B on :18091 (`start-35b-batch.sh`, `bin-19173f9e`) before the Sunday window, 09:30 restore inside it | **Cancelled.** :18091 is never restored with the 35B or any outside weights. Do not run `start-35b-batch.sh` or `q36-extra`. | Queen decision 2026-11-06T21:27:40Z; Drake 2026-11-06 (DRA-162): 35B retired, no outside weights |
| :18091 rollback target = the 35B | Recovery target = the last **verified own Omega LLM manifest**, else a clean stop (`down`) | DRA-125 deployment contract, step 4 |
| GPU rows only in the Sunday 06:00–10:00 America/Chicago window | The Sunday window stays the default slot. GPU rows that a current recorded delegation covers (DRA-162: the 2026-11-06 work and the DRA-125 cutover) run when their lease comes up. Seven consecutive nights are a separate decision (DRA-163); this runbook does not supply them. | DRA-118, DRA-162, DRA-163 |
| `spark-baseline 27b` per window | **Retired.** It times outside weights on :18091. Do not run it. An own-model baseline replaces it only after an own manifest serves :18091 (owner: lead `ownmodel`). | Model policy |
| SI e2e rows 5–7 on the shared Spark | **BLOCKED twice**: the install step needs a stock or clean-account target (DRA-55/DRA-163), and SI #62 `6295d38a` `installer/share/model.manifest` downloads `qwen3.6-35b-a3b-fp8-95a723d0` (37,493,015,668 bytes, retired outside weights). They run only after the SI installer is retargeted to the own model. | `r-si-e2e.md`; manifest read 2026-11-06 |

Historical receipts keep their identities. The 2026-11-06 rows (receipt folder
`~/handoffs/hive/gpu-2026-11-06/`) are indexed by `ROWS.tsv` in that folder (section 6).

## 2. State observed at writing (2026-11-06, 23:3x UTC)

These are observations, not guarantees; re-read them before acting.

- :18091: nothing listening (`ss -ltnp`). Every lease of 2026-11-06 recorded `18091 health: DOWN` before and after.
- Own-model candidates (lead `ownmodel`): `ollm serve` on 127.0.0.1:18291 and :18292 under `tests/omegallm/serve-check.sh`,
  CPU only, reading checkpoint `ck60000.bin` (380,003,448 bytes, sha256 `a53ced72…`) from a `/tmp` path.
- `spark-window status`: no window open, no lock holders, empty line.
- GPU compute apps: one, the protected `omega-tool-model` round40 server (335 MiB). An exclusive lease does not stop it; never touch it.
- Consumers that still default to :18091 (from the parity read of `~/handoffs/hive/parity-35b.md`): allen-chat (public,
  P0), the Hermes gateway profile `aienmotor`, `local-coder`, opencode on the Spark, `aien-manager`/board status, and the
  guards `tlsfuzz-watch`, `q36-extra` and the heavy-job lock, which read "18091 up" as "the 35B is live".
- Installed `~/.local/bin/spark-window` (sha256 `05723bbd…`) differs from `tools/ops/spark-window` (`01ac196e…`):
  the installed copy lacks the L162 rule that a bare `close` only closes your own window. Until an operator reinstalls
  the committed copy, **always close by id** (`spark-window close <ID>`).

## 3. GPU turn order

One claimant holds the GB10 at a time, through `spark-window` only, never `/tmp/aien-gb10.lock` directly.

Rules for every lease:

1. Post one BOARD line before opening: name, issue, exact sha, command, expected duration, expected effects.
2. Build first (outside the window, on your claimed cores). Open with
   `spark-window open <name> --ledger <issue> --lease 20 --gb10 exclusive --wait` (or `--gb10 none` for programs that take
   the GPU lock themselves, as Core `abi-qualify --chip` does). An exclusive lease is at most 20 minutes; split longer work into legs.
3. Run the command with `timeout` below the lease, inside `spark-window run`.
4. Close **by id**. Record :18091 state after the close (`ss -ltn 'sport = :18091'`, plus `/health` if bound).
5. Add the row to the dated folder's `ROWS.tsv` and run the checker (section 6).
6. After a close, take a new `--wait` ticket for your next leg. The line is first come, first served, so other lanes
   interleave between legs. Do not hold windows back to back while someone waits.

Priority order, used when the queen asks a lane to step aside or decides who queues first (it never preempts a lease
already open; the courtesy rule of 2026-10-24 stands). It follows the directive order: correct dispatch, coordination,
integrated own-model serving, measured training capacity, training and evaluation, daily operation.

| # | Row | Issue | Owner | Gate to start | Notes |
|---|---|---|---|---|---|
| 1 | CUDApp #280 chip rows (hello_gpu + control, NVRM lifecycle, M16 requal) at each new head, then at the merge sha | DRA-154, DRA-158 | lane CudaInteg280e | head built | Already in line |
| 2 | CUDApp main rows at the #280 merge sha (supersedes the main `b774723f` FAILs, which were host-build failures) | DRA-158 | CudaInteg280e | #280 merged | Pre-merge PASSes do not qualify main |
| 3 | Own-model serving checks that touch the GPU, if any (`ollm serve` is CPU-only today, so the DRA-125 cutover itself needs no lease) | DRA-119, DRA-125 | ownmodel | candidate manifest frozen | Candidate ports 18291–18299 only |
| 4 | v4 GB10 training path qualification legs: CPU parity, peak memory, checkpoint save and restore, tokens/s | DRA-183 | ownmodel (OllmV4Gpu) | v4 GPU code on its branch, host tests green | One leg per lease |
| 5 | Rung 11 training legs, `geval` after each, driver detached | DRA-120 | ownmodel | a committed pre-registration (schedule + predicted held-out E) | Was BLOCKED on 2026-11-06 for missing pre-registration |
| 6 | Personalization pilot fine-tune | DRA-146 | dra146 | ownmodel names the base checkpoint | One lease |
| — | TensorFold baseline/profile rows | DRA-197 | TensorFoldSpark | Drake authorizes a measurement-only testbed on own weights | BLOCKED: the DRA-197 baseline used outside weights (Qwen3.5-2B); DRA-198..200 held (queen DECISIONS 2026-11-07T00:00:56Z). Not schedulable here until then |
| — | D8 process tax | DRA-158 | CUDA lane | `hello_gpu` prints its overhead line | NOT_RUN until then; no ad-hoc substitute |
| — | Core alpha pipeline GPU gates | DRA-41 | Core lane | an alpha tag and signature, and the CUDApp #106 decision | BLOCKED; agents do not tag or sign |
| — | SI e2e ×3 | DRA-55 | SI release lane | stock/clean target and an own-model installer | BLOCKED (section 1) |
| — | :18091 DRA-23 backend identity | DRA-23 | ownmodel with the queen | an own manifest serving :18091 | Re-scoped from the 35B to the own model |

The recurring Sunday window holds at most 12 exclusive 20-minute leases (Wolfram: 4 h / 20 min = 12). The 31 leases of
2026-11-06 held at most 31/3 h of chip time at the cap (Wolfram: 31 × 20 min); the measured time was much shorter.

## 4. :18091 recovery contract (with DRA-125)

Lead `ownmodel` owns the deployment (DRA-125). This section is the contract the schedule relies on; it does not start
or stop anything.

States of :18091:

| State | Meaning |
|---|---|
| `down` | Nothing bound. The truthful unavailable state; consumers get a connection error, never a stand-in. This is the state now. |
| `own:<manifest sha256>` | `ollm serve` started from one frozen manifest: checkpoint sha256, tokenizer sha256, `ollm` executable sha256, compiler sha256, exact launch argv and environment. The manifest file and the checkpoint it names live on a durable path, never `/tmp`. |

Transitions (the only ones allowed):

| Event | From | To | Condition |
|---|---|---|---|
| cutover m | any | `own:m` | m passed the DRA-125 freeze and pre-registered acceptance on a candidate port (18291–18299), and the consumers in section 2 were checked against it. Otherwise refused and the state is unchanged. |
| crash | any | `down` | the process died; record it |
| stop | any | `down` | clean stop, no orphan work |
| recover | any | `own:last` or `down` | restart from the last verified manifest; with none, stay `down` |
| restore 35B / outside weights | — | — | **removed**: no such transition exists |

Machine-checked: `docs/ops/proofs/Port18091.lean` models this table. `inv_reachable` proves that every state reachable
by any event sequence has :18091 `down` or serving a verified own manifest, and that the recovery target is verified.
Two negative controls prove the property fails for the retired plan (`bad_breaks`: a 35B restore transition) and for a
cutover that skips verification (`unchecked_breaks`). Checked with the `lean` MCP (Lean 4.35.0): no errors, no warnings,
axioms `[propext]` for all three. This proves the model of the plan, not any running service.

Before a cutover, from the parity read: allen-chat sends a 14,364-byte system prompt (median prompt 6,852 tokens)
while `ollm serve` at `c73d4f33` refuses templates over 4,000 bytes, takes one connection at a time and does not call tools.
Until aien-train #72 closes those gaps, a cutover would make allen-chat fail; that is a DRA-124/DRA-125 acceptance
question for `ownmodel`, not a reason to keep any outside model. The guards that treat "18091 up" as the 35B
(`tlsfuzz-watch`, `q36-extra`, heavy-job lock) must be retargeted before cutover (unclaimed item in `CLAIMS.md`).

Recovery rehearsal (DRA-125 step 4) runs on a candidate port first: start from the manifest, one real request, kill the
process, `recover`, one real request again, and record the time to recover. Only then on :18091.

## 5. Test scheduling (CPU and host)

- Host tests, builds and gates never need the Sunday window. They run on the lane's claimed cores under
  `taskset -c <cores> nice -n 10` (cores 3, 7 and 15 never), heavy ones through `quiet-build`. Kanban cards without
  their own cores use the queen pool 10–11 under `flock ~/handoffs/hive/queen/pool-10-11.lock`.
- Timings are measurements: inside a window (`--quiet exclusive`), with the window id in the receipt. Value checks that
  compare outputs only may use `--quiet none`.
- The own-model acceptance suite (DRA-124) and `serve-check.sh` run on ownmodel's cores against candidate ports only.
- Anything that installs into the shared account, resets the machine or downloads outside weights is not schedulable here.

## 6. Receipts: `ROWS.tsv` and its checker

Every dated receipt folder (`~/handoffs/hive/gpu-<date>/`) carries one `ROWS.tsv`: one line per lease, plus one line per
row that took no lease. Format `window-rows v1`, checked by `tools/ops/window-rows/rows.om` (seeded Omega, pinned
compiler); rules in [`tools/ops/window-rows/README.md`](../../tools/ops/window-rows/README.md). It makes the DRA-118
acceptance mechanical: every row has PASS, FAIL, NOT_RUN or BLOCKED; PASS needs an exact sha, a window id and a closed
lease; FAIL needs an exact sha; a lease past its time cannot PASS; and every row records :18091 as `down` or
`own:<manifest sha256>`, so the 35B or anything else is refused.

```sh
rows < ~/handoffs/hive/gpu-2026-11-06/ROWS.tsv
# ROWS PASS rows=37 pass=17 fail=15 not_run=2 blocked=3 leases=31
```

The 2026-11-06 ledger is also the fixture `fixtures/good-20261106.tsv`. Its 31 lease rows match the 31 lease records
(`raw/*.meta`) in that folder.

## 7. Open items and owners

| Item | Owner | Next action |
|---|---|---|
| Frozen own manifest, durable checkpoint path, supervisor line for :18091 | ownmodel | Answer the BOARD contract note of 2026-11-06T23:46Z; DRA-125 steps 1–5 |
| Consumer parity (#72) and guard retargeting | ownmodel; unclaimed guard item | Close the gaps above before cutover |
| Reinstall the committed `spark-window` (L162 close rule) | queen (operator) | Copy-then-rename per `tools/ops/README.md`, after checking no window is open |
| Seven-night acceptance | queen (DRA-163) | Record the decision in `~/handoffs/hive/queen/DECISIONS.md` |
| SI installer still names the 35B | linear lead, SI release lane | Retarget DRA-55/SI #62 to the own model |
