# Doctrine consistency check (seeded `.om`)

Owner: [aien-architecture-mv #316](https://github.com/aien-dev/aien-architecture-mv/issues/316)
under [#300](https://github.com/aien-dev/aien-architecture-mv/issues/300); the check itself is
aien-architecture#7. Status: **replaces `scripts/check_doctrine.sh` (bash + GNU grep + gawk);
byte-for-byte parity on a 40-case corpus; wired into the `doctrine` gate step.**

Two native Omega programs, built only by the pinned seed compiler named in
`../zero-legacy/omega.pin` (`seed/out/omc` of `aien-dev/omega-mv` at `a0eafa39`, sha256
`734f0a39…6b61`). No C, Rust, Python, shell or foreign regex engine is on their implementation
path: every ERE of the old script is a hand-written matcher in `doctrine.om`, with the ERE kept
in a `note` above it.

| Program | Role |
| --- | --- |
| `doctrine.om` | the checker: `doctrine [ROOT]` (ROOT defaults to `.`) |
| `gate.om` | the gate runner: builds `../zero-legacy/sha256.om` and `doctrine.om`, checks the compiler against the pin, runs the checker on ROOT, prints `AIEN-OBS` lines |
| `gate.sh` | independently authenticate `$AIEN_OMC` before compiling `gate.om`, then exec it |
| `corpus.sh` | the parity corpus runner (needs the retired bash oracle; see below) |

## Contract (unchanged from the bash script)

Inputs under ROOT: `doctrine/*.md` and `docs/milestone-*-spec.md` in bash's `LC_ALL=C` glob
order (byte order, no dotfiles, `[ -f ]` after following symlinks). Text between
`<!-- HISTORICAL-PROVENANCE:BEGIN -->` and `<!-- HISTORICAL-PROVENANCE:END -->` is blanked with
line numbers kept (historical provenance is never checked).

Checks, in output order: 0 `unbalanced-historical-marker` (raw file); 1 `alpha-naming`,
`fixed-el1-handoff`, `obsolete-m27-closure`, `obsolete-roadmap-generation`,
`retired-milestone-identifier`, `status-outside-roadmap` and `duplicate-roadmap-table` (the last
two exempt `doctrine/ROADMAP.md`); 2 `physics-zero-range`; 3 `roadmap-missing` /
`roadmap-structure` (41 rows M0-M40, closed status list, era ranges); 4
`milestone-number-mismatch` (a code cited under a number other than its ROADMAP row, both
`Milestone N (`CODE`)` and `CODE (MN)` spellings).

Output: `FAIL [check] file:line: text` per finding (check 1 text is the line with leading
`[[:space:]]` removed and cut to 160 bytes; checks 2 and 4 print the whole line), then the
70-dash rule, `check_doctrine: scanned N files; F failure(s); 0 deferred finding(s).` and
`check_doctrine: PASS` or `check_doctrine: FAIL`. Exit 0 pass, 1 fail, 2 when ROOT cannot be
entered (`check_doctrine: cannot cd to ROOT` on stderr). The DEFERRED allowlist of the script was
empty, so the deferred count is the constant 0.

Byte semantics throughout, as the script had under `LC_ALL=C`: `\b`/`\<` word characters are
`[A-Za-z0-9_]`, `[[:space:]]` is bytes 9-13 and 32, and gawk's bracket `[-–]` in check 2 is the
four bytes 45, 226, 128, 147, so an en dash range such as `M27–M35` never matched there (grep's
`(-|–)` in check 1 does match the three-byte en dash). Both behaviours are reproduced.

## Build and run

```
AIEN_OMC=/path/to/seed/out/omc tests/gates/run.sh doctrine     # the gate step
# or by hand
$AIEN_OMC < tools/doctrine/doctrine.om > doctrine && chmod +x doctrine
./doctrine /path/to/checkout
```

`gate.sh` authenticates `AIEN_OMC` against the reviewed `../zero-legacy/omega.pin`
using trusted system `sed` and `sha256sum` **before invoking the candidate compiler**.
This is a temporary external bootstrap boundary, not a completed all-.om cutover.
Native self-hashing is defense in depth, not independent authentication. This assumes
trusted OS/tools/pin and a compiler file not concurrently replaced. Separate build
commands stop on failure rather than falling through to an older gate binary.

`gate.sh` exits 3 (NOT_RUN) when `AIEN_OMC` is unset, not executable, mismatched, or produces no program;
`gate.om` exits 3 when the compiler's native sha256 differs from `omega.pin`; otherwise its exit
is the checker's (0/1/2) and it prints `AIEN-OBS doctrine_sha256 "<sha256 of build/doctrine>"`
before the run and `AIEN-OBS doctrine_exit N` after it. The gate manifest
`tests/gates/arch-doctrine.gate` is `requires: host` (the compiler is AArch64 only), so the hosted
x86 AIEN Checks job skips it. The hosted `AIEN Pinned-omc Gates` job runs it on an
`ubuntu-24.04-arm` runner with omc born from seed-0 at the `omega.pin` commit (#363).

## Oracle and corpus

Oracle: `scripts/check_doctrine.sh` as of `1adbb2a` (sha256 `ea5c9069…b68a`), run with
`PATH=/usr/bin:/bin` (GNU grep 3.11, gawk 5.2.1, GNU sed 4.9, coreutils 9.4) on the Spark.
Recover it with `git show 1adbb2a:scripts/check_doctrine.sh > /tmp/oracle.sh`.

```
sh tools/doctrine/corpus.sh /tmp/oracle.sh ./doctrine [REPO-ROOT]
```

40 cases: the real tree (PASS, 30 files) plus 39 mutated copies under a scratch directory, one or
more per check and per regex branch, including: every status tag spelling and `[REOPENED` with
and without a closing bracket; wrong milestone numbers in both citation syntaxes, with
`Milestones`, `MILESTONE`, bare `M`, underscores and backticks in the gap, two citations on one
line, a `M05` roadmap row (string comparison `5` vs `05`), a duplicated code (last row wins), a
missing roadmap, a roadmap that is a directory, a roadmap with no rows, short rows, extra rows,
rows inside a historical block; second BEGIN, stray END, BEGIN+END on one line, unterminated
BEGIN; `28-milestone`, `Twenty-eight precise milestones`, `^MILESTONE N  — `, `M1–M27`; every
alpha/EL1/retired-identifier literal with word-boundary negatives (`alphabet`, `SENTINEL_GATE_12`,
`éALPHA`); physics-zero ranges with spaces, en dash, a dot inside the 30-byte window, and the
longest-match case `Physics Zero (see M1-M2) M27-M35`; CRLF files, a file without a trailing
newline, empty files, a 300-byte line with leading tab/space/CR (strip + 160 cut), extra files
that test glob order and exclusion (`Aa.md`, `ZZ.md`, `_under.md`, `.hidden.md`, a directory
named `sub.md`, a symlink to a file, a dangling symlink, `milestone--spec.md`,
`Milestone-9-spec.md`, `milestone-spec.md`), a relative ROOT and a missing ROOT.

Result (2026-10-24, `build/doctrine` sha256 `14eb7d84…6edb`): **40/40 cases identical** in
stdout and exit code. For the missing-ROOT case bash additionally prints its own
`cd: …: No such file or directory` diagnostic before the script's message; the corpus compares
the script's own stderr line, which is identical.

## Preserved quirks (reproduced, not corrected)

- A second `BEGIN` before an `END` makes the awk print the duplicate's line number and `exit`;
  awk's `exit` still runs the `END` rule, which prints the first BEGIN's line too. The report is
  therefore `FAIL [unbalanced-historical-marker] f:33\n32: HISTORICAL-PROVENANCE marker without
  partner` (two lines). Same in `doctrine.om`.
- The roadmap row counter is an unset awk variable until the first row passes: `expected row M,
  found M1` (no digit) and `found ` (no digit) when the roadmap has no rows.
- Check 4 compares the cited digits with the roadmap digits as strings (`5` differs from `05`).

## Limits

- Buffers: a scanned file is read into an 8 MiB pool (longer files are truncated), at most 1024
  files and 65536 bytes of file names, 512 roadmap codes, lines and files of at most 999,999
  bytes/lines (an overrun traps, exit 104). The real corpus is 30 files, 608 KB, longest line
  1197 bytes.
- A roadmap row number with more than 19 digits wraps where awk would print a float; files that
  exist but cannot be opened are treated as empty where the script would print an awk/grep
  error. Neither occurs in the repository and neither is in the corpus.
- `ROOT` defaults to `.`; the script defaulted to its own parent directory, which a program with
  no fixed location cannot know.

NOT_RUN: nothing in this directory runs under the hosted x86 workflow (AArch64 compiler only);
`aien-test run ARCH-DOCTRINE` was not run here, only `tests/gates/run.sh doctrine`, which is also
what the hosted AArch64 job runs.

## Bootstrap rejection regression (NOT_RUN)

This loader repair does not change `doctrine.om`, its matching rules, the gate manifest,
or the author's 40-case parity receipt above. Native execution of the changed loader
and the sentinel procedure below is NOT_RUN; older receipts do not qualify this head.

From the repository root in an isolated fixture checkout, with `AIEN_OMC` an absolute path already
independently verified against the pinned digest, use the shared native sentinel:

```sh
set -eu
ROOT="$PWD"
cd tools/doctrine
mkdir -p build
"$AIEN_OMC" < ../zero-legacy/fixtures/loader-sentinel.om > build/loader-sentinel
chmod +x build/loader-sentinel
rm -f build/untrusted-compiler-ran
if build/loader-sentinel; then rc=0; else rc=$?; fi
[ "$rc" -eq 98 ] && [ -f build/untrusted-compiler-ran ] || exit 1
rm -f build/untrusted-compiler-ran
if AIEN_OMC="$PWD/build/loader-sentinel" sh ./gate.sh "$ROOT"; then rc=0; else rc=$?; fi
[ "$rc" -eq 3 ] && [ ! -e build/untrusted-compiler-ran ] || exit 1
```

The direct-run precondition proves the sentinel creates the marker before checking that
the loader rejects it without execution. The zero-legacy loader has its own equivalent
procedure in its README; both loaders require independent rejection receipts.
