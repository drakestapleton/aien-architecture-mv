# name-check

Refuses new uses of the retired project names ([ADR 0038](../../docs/adr/0038-names-aienux-kernel-aienos-system.md)):
**Aienux** is the kernel, **AienOS** is the whole system, and **Aienix** is retired.

`namecheck.om` reads a git diff on standard input and judges every added line:

- `Aienix` / `AIENIX` are refused everywhere outside quoted text, also inside a longer word or an
  identifier (`AIENIX_MODE`): another company uses the name.
- `AIENOS` / `Aienos` are refused when they stand as a word in prose, including prose compounds:
  `AIENOS-based`, `AIENOS-Omega`, `AIENOS/Aienux`, `AIENOS-2 release`, `non-AIENOS`.
- Code passes: lowercase names (paths, crates, URLs, the aienos.com address), identifiers that only
  contain the word (`AIENOS_DISK`, `AienosCapRef`), labels and path parts where `-` or `/` is
  followed by a token of uppercase letters or digits that runs on to the next `-`, `/` or `_`
  (`AIENOS-PKV-ENVID-KEY-V1`, the key-derivation label `AIENOS/M5/CORTEX-V1`), path parts joined by
  a backslash (`\EFI\AIENOS\MODEL.MAP`) and file names (`AIENOS.md`). These change with their own
  tests, never with prose; renaming a key-derivation label would change the derived keys. A path
  part after `/` (`Atlas/AIENOS`) also passes: it cannot be told from a directory name.
- Quoted text keeps its words: code spans, double quotes and curly quotes (older documents and
  program output are quoted as they were written).
- History is never judged: `evidence/`, `receipts/` (at any depth), `docs/history/`,
  `docs/archive/`, `CHANGELOG*` (at any depth), this tool and ADR 0038 itself, and glossary lines
  starting `_Avoid_:`.
- Other ADRs, dated audits and reports are judged on purpose. They are history and are not edited
  (the 2026-11-15 rename left them as written); a new ADR, audit or amendment is new text and uses
  the current names, so an added line in an old one is new text too.
- A file's path comes only from its `+++` line inside the diff header (after `diff --git`, before
  the first `@@`), so added text that looks like a header cannot move the following lines into an
  allowed path. The TAB git adds after a path that holds a space is dropped.

It prints one line per finding and `name-check: FAIL` (exit 1), or `name-check: PASS (N added
lines checked)` (exit 0; an empty diff, where nothing changed, passes with 0 lines). Exit 2 is a
clean refusal with nothing judged, and one line on standard output names the reason: the input is not a git
diff (an added line or hunk before any `diff --git` header); a `+++` header is neither
`+++ b/PATH` nor `+++ /dev/null` (a diff made with `diff.noprefix`, or a file name git C-quotes
because it holds a `"`, `\` or control byte); the input cannot be read; a path is longer than 4096
bytes (PATH_MAX); or one line is longer than 16777216 bytes (the largest array the compiler builds).
A file the tool cannot judge is refused, never skipped.

## Run it

```sh
AIEN_OMC=/path/to/pinned/omc sh tools/name-check/gate.sh . [BASE]
# or through the gate entry point:
AIEN_OMC=/path/to/pinned/omc tests/gates/run.sh name-check
```

`gate.sh` checks `AIEN_OMC` against `../zero-legacy/omega.pin` (otherwise NOT_RUN, exit 3), writes
the change under review to `build/change.diff` (`git diff -U0 --no-textconv --src-prefix=a/
--dst-prefix=b/` from the merge base of BASE, default `origin/main`, else `HEAD~1`, to `HEAD`; the
fixed prefixes override any `diff.noprefix` or `diff.mnemonicPrefix` setting), and runs `gate.om`.
`gate.om` hashes the compiler again with the native `sha256.om`, builds `namecheck.om`, and requires
six fixtures to give exactly their recorded exit and output, counting those that pass
(`name_check_fixtures`), before it judges the change:

| Fixture | Exit | Output | What it holds |
|---|---|---|---|
| `fixtures/red.diff` | 1 | `red.out` (20 findings) | every retired form, an `AIENIX_` identifier, compounds, a word outside a quotation, unmatched quotes, line numbers inside a hunk, a fake header line, a path with a space |
| `fixtures/green.diff` | 0 | `green.out` | the new names, identifiers, labels, backslash path parts, file names, every history path (also nested), the glossary line, each kind of quotation |
| `fixtures/long.diff` | 1 | `long.out` | one added line of 1000017 bytes with the retired word at its end (longer than one inner loop) |
| `fixtures/refuse.diff` | 2 | `refuse.out` | a file name git C-quotes |
| `fixtures/nohdr.diff` | 2 | `nohdr.out` | an added line before any `diff --git` header |
| `fixtures/pathmax.diff` | 2 | `pathmax.out` | a `+++` path of 4097 bytes |

The first four are real `git diff` output made with the same options as `gate.sh`; `nohdr` and
`pathmax` are written by hand, because git cannot produce them. The line-length refusal (a line over
16777216 bytes) has no fixture, so as not to commit 16 MB; it was checked by hand (exit 2).

To check another repository's change with the same tool, build it and pipe that repository's diff in
with the same options:

```sh
"$AIEN_OMC" < tools/name-check/namecheck.om > /tmp/namecheck && chmod +x /tmp/namecheck
git -C OTHER -c core.quotePath=false diff --no-color --no-ext-diff --no-textconv \
  --src-prefix=a/ --dst-prefix=b/ -U0 "$(git -C OTHER merge-base origin/main HEAD)" HEAD | /tmp/namecheck
```

The gate runs only in this repository. Another repository would need its own copy or a pin of this
tool in its own gate files; that is not done here, because a copied file would have to be kept in
step by hand.

## Compilers

`namecheck.om` and `gate.om` compile with the repository pin (omc `734f0a39…`, omega-mv `a0eafa39`)
and with the newest omega-mv build at the time of writing (omc `26540e6d…`, omega-mv `e4271abd`).
Every loop bound stays at or under 999999, the largest bound the pinned compiler accepts. A loop that
passes its bound stops the program (trap 4), so each long scan is an outer loop of at most 17 passes
around an inner loop that ends one pass below its bound (17 x 999998 >= 16777216 bytes).

## The bash tool it replaces

This tool replaces the bash `name-check.sh` of the unlanded branch `naming/name-check-gate`
(`90296b21`). On real diffs (the reverts of the twelve naming branches of 2026-11-15, which add
the retired words back on 681 lines) the Omega tool reports every one of the bash tool's 675
findings, byte for byte, with each compiler, and 6 more: prose compounds such as `AIENOS-native`
that the bash tool passed. It also refuses what the bash tool passed silently: a fake header line
inside added text, a diff made with `diff.noprefix` and C-quoted file names. The bash tool's `--allow GLOB` option is not carried over: no caller used it, and an
allowance outside the tool's own reviewed table would not be reviewed.
