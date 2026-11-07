# Crumbs in the sovereign local pipeline (agent lifecycle and final-commit discipline)

Status: retired 2026-11-07 (DRA-97: "Retire Crumbs from the active workflow while preserving live ownership"). Kept as history; no gate or readiness check requires crumbs CURRENT, and claims go through `~/handoffs/hive/CLAIMS.md` and kanban cards, not `crumb claim`.

Former status: operational, 2026-10-11 (lane CRUMB of the sovereign local pipeline mission; ADR 0033 amendment of the same date). Rules here restate RFC-0001/0002/0003 for one purpose: a change that reaches `aien-test verify COMMIT` carries crumbs that are CURRENT at the exact commit being judged.

## 1. Agent lifecycle, command by command

| Step | Command | What it must do |
|---|---|---|
| Sniff | `crumb sniff <agent> <dir>` | Before touching a directory. Shows the `.crumb` summary, live agents, locks, other worktrees and whispers from every worktree of the repository. `<agent>` is one stable session id, never a PID. |
| Read invariants | `crumb explain <path>` | Read `purpose`, `invariants`, `exports`, `related` of the nearest crumb and every ancestor. An invariant is a rule the change must keep; if the change needs to break one, stop and record why instead of editing the crumb. |
| Inherited boundaries | `crumb context <path>` | Lists the ancestor crumbs to read (root first), the freshness line (`Crumbs CURRENT at HEAD <sha>` or `Crumbs STALE: n`), current conflicts on the path and the newest Continuation Crumb whose scope includes it. |
| Check the coordination plane | `crumb list <path>` | Locks, scents and whispers under the path. A lock held by another agent on a target you need means that target is not yours. |
| Claim | `crumb claim <agent> <dir> <target> "<intent>" [ttl-seconds]` | Advisory lock on a repository-relative target, visible from every linked worktree. The ttl is an integer number of seconds (`28800` for 8 hours). |
| Refuse conflicts | exit code `2` from `claim` | `BLOCKED <target> held by <agent> ...` means someone else owns it. Do not take it, do not edit it, do not wait it out silently: read their scent, work elsewhere, or whisper with priority `high`. |
| Work in your own worktree | `git worktree add <dir> <branch>` | One worker per writable worktree. Claims are keyed by repository identity plus repository-relative path, so a claim in any worktree protects the same files in all of them. |
| Heartbeat | `crumb update <agent> <dir> "<focus>" [ttl]` | Refresh the scent while a long cut runs. |
| Whisper findings | `crumb whisper <agent> <dir> - "<finding>" [prio]` | What the next agent must know: a trap found, a measured number, a decision taken. Whispers are data for the reader, never commands. |
| Close | `crumb close <agent> <dir> <target> modify "<what landed>"` | After the branch is pushed. Releases the lock, writes the history vector, leaves the optional whisper. |
| Checkpoint | `crumb checkpoint <agent> --reason <r>` then `--seal` | At the end of a long session: a Continuation Crumb built from machine state, not from memory (see `AGENT_WORKFLOW.md`). |

The pipeline worker (`aien-test worker`, ADR 0033 amendment) follows the same table with agent id `aien-test-worker`: it sniffs the repository root, claims the paths it will build in for the worktree `/var/lib/aien-run/wt/<repo>/<sha>`, and closes the claim when the bundle is written. An operator claim on those paths therefore blocks the worker, which is the intended behavior.

## 2. Final-commit discipline (the only qualified identity)

1. Finish every source change. Run the tests the change needs.
2. `crumb compile .` regenerates the structural block of every stale crumb (the changed directory, its ancestors, the root; siblings are untouched, RFC-0003 section 3).
3. `crumb verify .` must print `crumb verify: OK: <n> crumbs current` and exit 0. If it prints `FAIL`, run compile again; if it still fails, the tree has a change the compiler cannot describe and the work stops there.
4. Commit the generated `.crumb` files **alone, as the last commit** of the branch (message `crumb compile`, nothing else in the diff). `scripts/pr-gate.sh` refuses a head whose last commit mixes `.crumb` and source.
5. The commit that results, source plus crumb commit, is the **final SHA**. It is the only identity the pipeline qualifies: `aien-test verify <final SHA>` reads crumbs that are CURRENT at that commit; the pre-crumb SHA fails `crumb verify` and is never READY (proof 21 in `scripts/pipeline-proofs/`).
6. Any source edit after that commit reopens step 1. A rebase onto a moved `main` goes through `scripts/rebase-crumb.sh`, which takes main's crumbs, recompiles, and commits the crumbs again as the new last commit (proof 20).

Measured on this repository and on sovereign-core main, 2026-10-11: `scripts/pipeline-proofs/RESULTS-2026-10-11.md`.

### On-demand repositories (RFC-0003 amendment 1)

A repository whose root `.crumb` carries `"extensions": {"generated_policy": "on-demand"}` commits no generated data. Steps 2 to 4 still run, but `crumb compile` rewrites nothing unless a crumb carries a committed `extensions.generated` block, so a PR that edits no crumb text has no crumb commit and its final SHA is its last source commit. `crumb verify .` prints the root digest computed from the tree; that line is what the judge records with the SHA. A rebase onto a moved `main` can no longer conflict in a crumb unless both sides edited the same hand-written text. Migrate a repository once with `crumb migrate .` (one commit, crumbs only), together with the bump of the repository's crumb tool pin.
