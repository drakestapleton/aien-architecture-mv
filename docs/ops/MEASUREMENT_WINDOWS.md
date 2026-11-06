# Measurement windows and the shared base

> **Correction 2026-11-06 (DRA-118).** The 27B/35B models on 127.0.0.1:18091 are retired and outside
> weights are not used, so `spark-baseline 27b` and every "27B baseline" step below are historical: do not
> run them. :18091 is either down or serves a frozen own Omega LLM manifest. The GPU turn order, the
> :18091 recovery contract and the per-folder `ROWS.tsv` receipt ledger are in
> [SPARK_TEST_SCHEDULE.md](SPARK_TEST_SCHEDULE.md). The installed `spark-window` lacked the L162 close rule
> when checked that day, so close windows by id.

Several agents measure on the one Spark at the same time. When three of them timed things in parallel
on 2026-10-19, two of the three verdicts came back INCONCLUSIVE only because the box was loaded by the
others. Drake's rule: build once, measure the shared parts once per window, and then each agent measures
only its own difference, one after another.

The shared base is four small shell tools in `~/.local/bin` (copies in [`tools/ops/`](../../tools/ops/README.md)):

| Tool | What it does |
|---|---|
| `spark-build-once` | Builds a source tree once. A second caller with the same source gets the stored result in seconds. |
| `spark-window` | Opens one measurement window at a time, keeps the box quiet while it is open, records the box state at open and close. |
| `spark-calibrate` | The one calibration of a window: CPU memory bandwidth and idle power at the wall. |
| `spark-baseline 27b` | The one 27B baseline of a window: a fixed 64-token reply, tokens per second and joules per token. |

`spark-receipt` (the energy receipt every measurement already uses) now stamps the window id and the
window's calibration file into each receipt. It is shell and awk now; the keys, file name and output
are the same as before, plus the two new keys.

## The run order

1. One window at a time. `spark-window open` refuses when a window is already open or waiting, and
   shows whose it is.
2. To wait your turn, add `--wait`: you get a place in line and your window opens when everyone
   ahead of you is done, first come, first served. While anyone is in line, an `open` without
   `--wait` is refused, so nobody jumps ahead. Say so on the ledger:
   `ledger note <your id> "measure: in line for a window"`. `spark-window status` shows the line.
   (Retrying a refused `open` every 15 s lost the turn for four hours on 2026-10-20; that is why the
   line exists.)
3. Inside your window: calibrate once, take the 27B baseline once (if your work involves the 27B),
   then run only your own measurements. Every receipt carries the window id, so a reader can match it
   to the calibration and the baseline taken under the same conditions.
4. Close the window as soon as your timings are done. A window that holds anything exclusive (the
   default) lasts at most 20 minutes and `open` refuses a longer `--lease`; other windows default to
   90 minutes. A window that runs past its lease lets its locks go, writes NO VERDICT in its folder
   and posts on the board: its timings are not valid (L405, Drake 2026-10-22). Split long measurements.
5. A timing window opens only when the machine is quiet anyway: at most 3 jobs on the quiet lock and
   a 1-minute load of at most 10. It waits for that holding nothing (L405).

Builds are not measurements: do them before you open the window, through `spark-build-once` or
`quiet-build`. While a window is open, builds wait, but at most 25 minutes; then they run anyway and
the window is marked "shared machine" (L405).

## Exact commands

Open a window that will run the commands below, including `spark-baseline` (waits its turn; prints the
window id when it holds the box). `spark-baseline` refuses a window that holds the GPU lock, so this
open passes `--gb10 none`:

```sh
id=$(spark-window open my-measurement --ledger L109 --lease 20 --gb10 none --wait)
```

By default `open` holds the GPU lock (`--gb10 exclusive`, added by L154), so GPU-only jobs cannot run
inside it. The 27B server takes that lock itself for every reply, so a window that measures the 27B
server, including `spark-baseline`, must be opened with `--gb10 none`; `spark-baseline` refuses
otherwise. A window that does not measure the 27B can leave that default and skip `spark-baseline`.
To hold the GPU lock for other work and still take a 27B baseline, use two windows: the default for
the GPU-holding work, and `--gb10 none` for `spark-baseline`. `spark-calibrate` works in both: it
uses the window's GPU lock when the window holds it and takes the lock itself when it does not.

Calibrate and take the baseline inside it:

```sh
spark-window run spark-calibrate
spark-window run spark-baseline 27b
```

Run your own measurement inside it (any command; `spark-receipt` inside picks up the window id):

```sh
spark-window run spark-receipt my-run --idle 30 -- ./my-benchmark args
```

Close it:

```sh
spark-window close "$id"
```

A bare `spark-window close` closes the open window only if you own it: the shell that ran `open` is
in your process tree, or `$SPARK_WINDOW` (set by `run`) is its id. Otherwise it refuses with exit 3
and names the holder (L162, 2026-10-20: one lane's finishing script closed another lane's window).
`spark-window close <ID>` closes exactly that window.

See what is open and who holds or waits on the locks:

```sh
spark-window status
spark-window locks
```

Build once (from inside a git worktree; name every result you need with `--out`):

```sh
spark-build-once --out build/dagsim -- make build/dagsim
```

## What lands on disk

Everything for one window sits in `~/yardsticks/windows/<window id>/`:

| File | Contents |
|---|---|
| `open.json`, `close.json` | Box state at open and close: load, free memory, GPU use and power, who holds the GPU and quiet locks, who waits, the latest sensor row |
| `calibration.json` | Memory bandwidth (median, lowest and highest of 10 copies, with 1 and 8 threads) and idle power at the wall over 30 s |
| `calibration/` | The raw probe output and the idle receipt |
| `baseline-27b.json` | Decode tokens per second, joules per token over the decode at the wall and above idle, the reply's fingerprint, the server build |
| `baseline-27b/` | The exact request, the reply, the arrival time of every streamed piece, the receipt, the GPU lock samples |

Receipts still go to `~/yardsticks/receipts/<date>-<name>.json` and now carry `window_id` and
`calibration` (both `null` outside a window). The build cache lives in `~/.cache/spark-build-once/`
and its log in `~/yardsticks/build-once.log`.

## How it works, in plain words

- **The quiet lock.** The hive already had one rule for keeping the box quiet: builds share
  `/tmp/aien-quiet.lock` through `quiet-build`, a measurement takes it alone through `quiet-measure`.
  A window is a long-running `quiet-measure`: a small holder process takes the lock alone and keeps it
  until you close the window or the lease runs out. Inside the window `quiet-measure` sees its own
  window and runs your command straight away instead of waiting on its own lock.
- **Getting both locks without starving (L154, L189, L322).** The window waits for the GPU lock
  holding nothing, so it never blocks CPU timings while it queues. Once it has the GPU lock it keeps it
  and raises a gate (`/tmp/aien-quiet.gate`): new `quiet-build` and `quiet-measure` callers wait outside
  while the ones already holding the quiet lock finish (L322: without the gate, shared takers kept
  arriving and the window waited 40+ minutes). It drains the quiet lock for at most 5 minutes, then
  lets everything go and waits for a quiet machine again (L405). If a process waiting for the GPU lock
  holds the quiet lock, the window lets the GPU lock go (gate stays up), waits for the quiet lock, then
  tries the GPU lock without blocking while keeping the quiet lock it won (L189: letting a won quiet
  lock go starved the window for hours). `--quiet none` takes the GPU lock only, for checks that
  compare values, never speeds.
- **The GPU lock.** `/tmp/aien-gb10.lock` is separate. The calibration holds it for its minute of
  probing and idling so the GPU stays idle. The baseline does not hold it, because the 27B server takes
  that lock itself for every reply; holding it would make the server wait on us forever. Programs that
  use only the GPU lock keep it busy almost all the time (the first window ran out its hour waiting for
  it to go quiet), so the baseline asks for the reply word by word and stamps each word as it arrives.
  From the first word to the last the server is holding the GPU lock for our reply, so the decode rate
  and its energy are clean however long the reply waited in the GPU queue. The baseline samples the
  lock table throughout and is marked not ok if anyone else held the GPU lock during the decode, or if
  the whole reply arrived in one burst (then nothing was timed).
- **The build cache key** is the source tree as it is on disk (the committed tree, plus uncommitted
  changes, plus new files that git does not ignore), the folder you run from, the exact command, the
  `--out` list and the `PHYSICS_DIR` / `AIENOS_LOCK_REPO` settings. Any change gives a new key, so a
  stored build is only reused for identical sources. Two callers with the same key at the same moment:
  one builds, the other waits on a per-key lock and then takes the stored result. Results are stored
  by an atomic rename, so a half-written entry is never visible.

## Limits, said plainly

- Wall power is the whole UPS output in 10 W steps about every 2 s, not the Spark alone. A 64-token
  reply lasts a few seconds, so its joules per token rest on a few samples: read it as coarse.
- The headline speed is the decode rate: words after the first, divided by the time from the first word
  to the last. The whole-request rate is recorded too, but it includes the wait in the GPU queue and the
  short prompt's prefill.
- Programs that take only the GPU lock and not the quiet lock can still run during a window. The
  window records them (lock holders at open and close; the baseline samples the lock during its
  decode), it does not stop them.
- The memory probe is the one research/583 used (omega `research/cost-sim-583@3bd56731`,
  `tools/dagsim/memcpy_probe.c`), built with `cc -O2 -pthread`; 583 did not record its compiler
  flags, so its numbers and ours are comparable in method, not guaranteed bit for bit.

## Receipt format: what changed

Same keys, same order, same file name, same output as before; two keys added at the end. Run side by
side on the same 8-second command, the old and new receipts differed only in timing jitter
(`start`, `seconds`, `wall_J` within 0.02 %) and these lines:

```diff
  "note": "wall W = UPS ups.load x 10 (CP1500PFCLCD, 1 percent steps, ~2 s); whole UPS output, not the Spark alone",
+ "window_id": "20261019T232138Z-103d00",
+ "calibration": "/home/drakestapleton/yardsticks/windows/20261019T232138Z-103d00/calibration.json"
```

Outside a window both are `null`. Numbers still print with a decimal point (`180.0`), as before.
