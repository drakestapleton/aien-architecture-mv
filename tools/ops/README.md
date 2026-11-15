# tools/ops: the Spark's shared measurement base

Shell tools installed in `~/.local/bin` on the Spark. These are the committed copies; install by copying
each file over the old one (copy to a temporary name, then rename, so running jobs keep the old file).
How and when to use them: [docs/ops/MEASUREMENT_WINDOWS.md](../../docs/ops/MEASUREMENT_WINDOWS.md).

| File | Purpose |
|---|---|
| `spark-build-once` | Build cache keyed by the source tree, command and env knobs; concurrent callers build once |
| `spark-window` | One measurement window at a time; holds the quiet lock exclusive; box state at open and close. A bare `close` only closes a window you opened (same shell tree, or `SPARK_WINDOW` set); otherwise refused with exit 3, use `close <ID>` |
| `test_spark_window_close.sh` | Offline test for the close rule above (scratch locks and folder, never the live windows) |
| `test-spark-window-starve.sh` | Offline test, scratch locks and window root only. Case 1: no contention. Cases 2 and 3: one and two shared holders take `$SPARK_QUIET_GATE` and then the quiet lock, the quiet-build order, so the gate at `spark-window:330-336` keeps new holders out and the drain finishes. Case 4 (chip busy): with the chip lock held for 6 s, the window waits for the chip and opens only after it is free. Plain `flock -s` skips that gate: one plain holder leaves only a timing-dependent gap, and two can starve an exclusive waiter, because Linux flock gives the waiter no priority. Those plain-flock cases (2p, 5) are skipped unless `SPARK_STARVE_PLAIN=1` |
| `test-quiet-lock-order.sh` | L217 replay (`quiet-lock-order/suite.sh`), scratch locks only. A measurement queued for a busy chip must not hold the quiet lock or raise the want flag. The fixed copy passes every check, the pre-fix copy (`quiet-lock-order/quiet-measure.pre-L217`) fails the starvation checks A1-A3, and six mutants of the fix each fail their own check. Exit 0 only when all three hold |
| `spark-calibrate` | Per-window calibration: memcpy bandwidth (omega#583 probe) and 30 s idle power at the wall |
| `spark-baseline` | Per-window 27B baseline: fixed 64-token streamed reply on 127.0.0.1:18091, decode tok/s and J/token |
| `spark-receipt` | Energy receipt for any command; now stamps `window_id` and `calibration` |
| `quiet-measure` | Exclusive quiet lock for a measurement; runs directly inside its own open window. L217: if the command starts with `flock LOCKFILE`, that lock is taken first while holding nothing, and the want flag is raised only after it is held, so a measurement queued for the GPU does not freeze builds |
| `quiet-build` | CPU-heavy jobs. Waits for a live measurement flag (at most 1 min), then the quiet gate, then a shared quiet lock. The whole wait is capped at 25 min (`SPARK_BUILD_MAX_WAIT`, default 1500 s). If the lock is acquired in time, the command runs as given. Past the cap it runs at nice 19, with no lock and no core pinning, and the open window is marked shared machine (L405). Waits are logged |
| `spark-cleanup` | Daily disk clean-up (04:00 timer, and under 20 % free). Removes regenerable build output, caches, old /tmp entries; removes a worktree only when its HEAD is present in `~/git` (the store Interplane serves), not merely on some remote. Class 8 is an alarm that never deletes: agent copies idle 3 days whose work is all in `~/git` (a finished task left its copy), copies with work missing from `~/git`, and model weights copied instead of linked; an `--apply` run posts one board line when they total 1 GB or more. Dry run by default; `--help` lists every class |
| `test-spark-cleanup.sh` | Offline test of classes 2 and 8 in a scratch home, git store and board: 11 cases and 5 mutants (store check always true, the old remote-only pushed check, no idle check, index rewritten by the checks, no board line), each mutant must fail a case |

`SHA256SUMS` in this directory is the sha256 of each script. It lists bare file names, so check it from
`tools/ops`: from the repository root, `(cd tools/ops && sha256sum -c SHA256SUMS)`. To check the copies
installed on the Spark, run `(cd ~/.local/bin && sha256sum -c --ignore-missing <repo>/tools/ops/SHA256SUMS)`.

Shown on the Spark (2026-10-19/20): two callers on one source built once in a scratch repo (the second
reused the stored result), two windows opened at the same moment (one refused), lease expiry, the
`--wait` line in a sandbox (turns in arrival order, a late open refused, a waiter that gave up dropped).
Real runs: two omega worktrees at one commit built once, identical output, a repeat in 4 s
(docs/ops/evidence/L113-build-once-two-worktrees.md); window 20261020T095626Z-bd2f56 with a calibration
and a passing 27B baseline (~/yardsticks/windows/20261020T095626Z-bd2f56/).
