# window-rows: the GPU-window row ledger checker (seeded `.om`)

Status: **IMPLEMENTED, EXERCISED on host (aarch64)** by `gate.sh` and on the real 2026-11-06 receipt
folder. It checks a ledger file; it does not open windows, read receipts or touch the GPU.

Why: DRA-118's acceptance is "each row has a receipt with PASS/FAIL on an exact sha, lease released, and
:18091 state recorded after every lease". `ROWS.tsv` states that per row and `rows` checks it, so the
acceptance is a command instead of a reading. Schedule and contract: [`docs/ops/SPARK_TEST_SCHEDULE.md`](../../../docs/ops/SPARK_TEST_SCHEDULE.md).

| File | Role |
| --- | --- |
| `rows.om` | `rows < ROWS.tsv`: exit 0 and `ROWS PASS rows=N pass=P fail=F not_run=X blocked=B leases=L` on stdout, or exit 1 and `rows: line N: REASON` on stderr at the first refused line |
| `gate.om` | gate runner: checks the compiler against `../../zero-legacy/omega.pin` with `../../zero-legacy/sha256.om`, builds `rows.om`, runs every fixture, prints `AIEN-OBS` lines |
| `gate.sh` | loader outside the programs: authenticate `$AIEN_OMC`, compile `gate.om`, exec it |
| `fixtures/` | `good-*.tsv` with their exact stdout in `good-*.out`; 32 `bad-*.tsv` with the exact stderr each must produce in `bad-*.err`; `good-20261106.tsv` is the real 2026-11-06 ledger |

Run (from anywhere): `AIEN_OMC=<omc 734f0a39…> sh tools/ops/window-rows/gate.sh`. Any other compiler, or none,
is NOT_RUN (exit 3).

## Format `window-rows v1`

Line 1 is exactly `# window-rows v1`. Every other line is one row: exactly 9 TAB-separated, non-empty
fields, LF line ends (a CR is refused), newline at the end, at most 512 bytes per line, at most 255 rows,
at most 131072 bytes in all.

| # | Field | Rule |
| --- | --- | --- |
| 1 | `row` | 1..48 bytes of `[a-z0-9._-]`, unique in the file |
| 2 | `issue` | `DRA-` and 1..5 digits |
| 3 | `repo` | `-` or `owner/name` (`[A-Za-z0-9._-]`, one slash) |
| 4 | `sha` | `-`, or 7..40 lowercase hex, optionally `+p:` and 8..64 hex naming the sha256 of a patch applied on top (a patched tree is not that commit) |
| 5 | `window` | `-` or a spark-window id `YYYYMMDDTHHMMSSZ-xxxxxx`, unique in the file |
| 6 | `verdict` | `PASS`, `FAIL`, `NOT_RUN` or `BLOCKED` |
| 7 | `lease` | `closed`, `expired` (ran past its lease: NO VERDICT) or `none` |
| 8 | `p18091` | :18091 after the lease: `down`, or `own:` and 12..64 hex (sha256 of the frozen own-model manifest). Anything else, such as `35b` or `up`, is refused |
| 9 | `receipt` | the receipt file, relative to the folder: 1..96 bytes of `[A-Za-z0-9._/-]`, no leading `/`, no `..` |

Rules between fields: `window` is `-` exactly when `lease` is `none`; `PASS` needs `sha`, `repo`, a window and
`lease` `closed`; an `expired` lease cannot be `PASS`; `FAIL` needs `sha` and `repo` (it may have no lease, when it
failed before reaching the chip). `NOT_RUN` and `BLOCKED` carry their reason in the receipt.

What it does not check: that the receipt file exists or says the same verdict, that the sha exists, or that windows
did not overlap in time (spark-window itself allows one at a time). Those stay with the reader of the receipt.

## Evidence (2026-11-06, Spark, omc sha256 `734f0a39…6b61`, cores 10–11 under the queen pool lock)

- `gate.sh`: `window_rows_good_ok 2`, `window_rows_good_total 2`, `window_rows_bad_refused 32`, `window_rows_bad_total 32`, exit 0.
- Compiler controls: a one-byte-changed compiler and an empty `AIEN_OMC` give exit 3 through `gate.sh`; the built gate
  run directly with the changed compiler also gives exit 3.
- Six source mutants of `rows.om` (drop the expired-PASS rule, accept any `p18091`, skip the duplicate-window check,
  skip the window/lease rule, accept 1-hex shas, accept a missing final newline) each make the gate exit 1, naming
  the fixtures that caught them.
- Size bounds: a 131072-byte input is read; 140017 bytes give `rows: line 0: input-too-large`; a directory on stdin
  gives `rows: line 0: read-error`.
- The real ledger `~/handoffs/hive/gpu-2026-11-06/ROWS.tsv` (= `fixtures/good-20261106.tsv`):
  `ROWS PASS rows=37 pass=17 fail=15 not_run=2 blocked=3 leases=31`, matching the 31 lease records in that folder.
