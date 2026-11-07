# tools/candidate: the candidate-manifest checkers in seeded Omega

Two first-party tools of `docs/qualification/CANDIDATE.md`, rewritten from bash into seeded
native Omega (`.om`) for the zero-legacy migration (#300, #316). They replace
`scripts/check_candidate.sh` and `scripts/check_candidate_pins.sh` (last at 1dd84d1) with the
same arguments, output ordering and exit codes, subject to the explicit differences below.

| program | usage | exit |
|---|---|---|
| `check_candidate.om` | `check_candidate <manifest.toml>` | 0 valid, 1 invalid (usage error: 1) |
| `check_pins.om` | `check_pins <manifest.toml>` | 0 every pin agrees, 1 any mismatch or read failure |

Build with the pinned seed compiler (`tools/zero-legacy/omega.pin`, `omc_sha256`
`734f0a39…6b61`): `$AIEN_OMC < check_candidate.om > check_candidate && chmod +x check_candidate`.
Each file is one unit; Omega has no `import`, so the shared part (parser, key table, process
spawning) is carried by both files, as `tools/zero-legacy/*.om` carry their own helpers.

What they check is unchanged and documented in `docs/qualification/CANDIDATE.md`: commit pins are
40 lowercase hex and exist (`gh api repos/aien-dev/<repo>/commits/<sha> -q .sha`, or the command in
`CAND_SHA_CHECK` run as `$CAND_SHA_CHECK <repo> <sha>`); executable digests are 64 hex and not all
zero, `UNBUILT` only while the status starts with `draft`; every `<stem>.amendment-<n>.toml` next to
the manifest is checked (schema, candidate, number, date and reason, `manifest-sha256` of the frozen
manifest computed natively, added keys only, never in `[commits]`, `[contracts]`, `[executables]`
or `[consumed_pins]`, `*-sha256` values real). `check_pins` fetches lock files
(`gh api -H "Accept: application/vnd.github.raw" repos/aien-dev/<repo>/contents/<path>?ref=<sha>`,
or `$CAND_FILE_AT <repo> <sha> <path>`) and compares them with the manifest's pins and
`[consumed_pins]`.

Two additions to `check_pins` since the bash (DRA-46, CAND-5 gaps G1 and G2; tested by the
extension cases below, never by the frozen oracle):

- **`-mv` sources.** A Cargo.lock `source = "git+https://github.com/aien-dev/<name>-mv..."`
  counts as `<name>` (issue 815; sovereign-core consumes `aien-protocols-mv` since #906 and
  `crumb-spec-mv`). The old and the `-mv` name are one pin, so two revisions across them are
  `several`. Any other suffix (`<name>-fork`, `<name>-mvx`) is not the repo.
- **In-tree contracts.** `[contracts] crumb-spec-consumed = "in-tree"` or
  `spark-crumbs-consumed = "in-tree"` states that sovereign-core builds that contract crate from
  its own tree (spark-crumbs since sovereign-core #892), the meaning of sovereign-core's own
  `[pins] spark-crumbs = "in-tree"` (`scripts/check-release-candidate.sh`, ce792cf5). Cargo.lock
  must then hold a path package of that name (a `[[package]]` with that `name` and no `source`
  line) and no git source for the repo under either name; the contract is then built at
  `[commits] aien-sovereign-core`, and its `[contracts]` commit (still required by
  `check_candidate`; CAND-5 keeps the archived revision CAND-4 consumed) is not compared with
  Cargo.lock. Any other value of the key is refused. Without the key nothing changes: a contract
  with no git revision fails as before, and when Cargo.lock holds a path package of that name the
  FAIL line says so and names the key. There
  is no in-tree form for `[commits] aien-protocols`. A frozen manifest cannot gain the key (an
  amendment may not touch `[contracts]`), so CAND-5 keeps its one named difference (spark-crumbs);
  later manifests state it.

One deliberate change from the frozen bash: the key `commits.aienos` names the kernel repository,
renamed to aien-dev/aienux, so `check_candidate` checks that pin as `<repo>` = `aienux`.
The original oracle outputs remain unchanged; the runner asserts this exact naming delta.

## The parsed TOML subset

Both programs parse exactly what the bash parsed, and every manifest and amendment under
`qualification/candidates/` and `scripts/testdata/` uses only this:

- `key = "value"` with an optional trailing `# comment` after the closing quote. Whitespace
  (space, tab, CR, VT, FF) may surround the key, the `=` and the value. The key is
  `[A-Za-z0-9_.-]+`; the value is any bytes but `"` (so a `#` inside the quotes is kept, and a
  quoted value cannot contain `"`).
- `[section]` with the same name alphabet, optionally followed by a `# comment`. Keys after it
  are stored as `section.key` until the next section line.
- Blank lines and `# comment` lines.
- A duplicate key keeps its last value. A final line without a newline is not read (bash
  `while read` stops there). NUL bytes are dropped from a line (bash `read` drops them).

Any other line (`key = 5`, `key = [..]`, `[[array]]`, `key = "a" "b"`, unterminated quotes) is
ignored, exactly as the bash ignored it; a required key written that way reads as missing and is
reported by the existing checks (`missing field`, `is not 40 lowercase hex`, `does not match its
file name`, ...). No new refusals were added because the frozen contract is byte parity with the
bash; the adversarial corpus below pins that behaviour (`wrong-type`, `dup-key`, `extra-section`,
`junk-lines`, `crlf`, `trailing-space`, `no-final-newline`, `nul-byte`, ...).

Keys read by `check_candidate`: `schema`, `id`, `status`, `created`, `commits.omega`,
`commits.aienos`, `commits.aien-sovereign-core`, `commits.aien-protocols`,
`commits.aien-architecture`, `contracts.crumb-spec`, `contracts.spark-crumbs`, optional
`commits.physics`, `commits.interplane`, every `executables.*`; in an amendment `schema`,
`candidate`, `amendment`, `date`, `reason`, `manifest-sha256` and the added `section.key` entries.
Keys read by `check_pins`: `commits.aien-sovereign-core`, `commits.omega`, `commits.aienos`,
`commits.physics`, `commits.aien-protocols`, `contracts.crumb-spec`, `contracts.spark-crumbs`,
the optional `contracts.crumb-spec-consumed` and `contracts.spark-crumbs-consumed`, and
every `consumed_pins.*` (`sovereign-core-omega-lock`, `sovereign-core-cargo-lock-aien-protocols`,
`omega-physics-lock`, `omega-aienos-lock`, `omega-argus-lock` are compared; any other name is
reported `SKIP`).

## Order of lines: bash associative arrays, reproduced

The bash walked `${!kv[@]}` for the `[executables]` checks, the amendment keys and the
`[consumed_pins]` loop. That order is bash 5.2's hash order, so the .om keeps its keys in a table
that walks the same way: FNV-1 (multiply first, offset 2166136261, prime 16777619, 32-bit) over
the key bytes, 1024 buckets, growth x4 when the entries reach twice the buckets, a new key at the
head of its bucket, walk buckets ascending. Verified against `bash 5.2.21` on 30 random key sets up
to 5000 keys (including growth) and by the corpus (`many-exe-bad`: 50 FAIL lines in bash order;
`amend-many-bad`, `many-consumed`).

## Children and the environment

A child (`gh`, or the `CAND_SHA_CHECK` / `CAND_FILE_AT` command, split on space, tab and newline
as bash splits an unquoted variable) runs as `/bin/sh -c 'set -a; . "$1"; set +a; shift; exec
"$@"' sh /proc/self/fd/N cmd args...` where fd N is a memfd holding this process's environment
as single-quoted shell assignments. Omega's `execprog` starts a child with an empty environment
and no PATH search; the replay gives the child the full environment (so a test's `PATH`,
`GH_STUB_LOG`, `PARITY_FILES` reach it) and `sh` does the PATH search. Only entries whose name is a
shell identifier are replayed. In `gh` mode `check_candidate` sends the child's stdout and stderr
to `/dev/null` as the bash did; `check_pins` captures stdout through a pipe (trailing newlines and
NUL bytes dropped, as `$(...)` does) and leaves stderr alone.

## Oracle and parity corpus (`parity/`)

`parity/run.sh <check_candidate> <check_pins> [record|record-extensions]` runs every case under `parity/cases/`
and compares stdout+stderr (one pipe, in order) plus `rc=N` with `parity/expected/`. The expected
files were recorded from the bash scripts at 1dd84d1 (`record`), before they were deleted; the
.om binaries must reproduce them byte for byte except for the exact naming delta below and the
named limits. 74 candidate cases and 43 pins cases: every
case of the two test suites, the live `CAND-0` and `CAND-4` manifests, the gh code path with its
argv log, and adversarial inputs (missing, duplicate and wrongly typed keys, extra sections,
CRLF, trailing spaces, no final newline, NUL and non-ASCII bytes, empty and junk files, 50 bad
executables, 24 bad amendment keys, three amendments, a directory where a file is expected,
command words in `CAND_SHA_CHECK`/`CAND_FILE_AT`, empty and comment-only lock files, several and
forked Cargo.lock revisions, an 800-package Cargo.lock). Expected result: **107 identical,
6 exact naming deltas, 4 named limits, 0 different**. A case with a `limit` file is a documented
difference: it is printed, not counted as a failure, and reported if it ever becomes identical.

The six naming cases are `gh-404-contract`, `gh-404`, `gh-good`, `gh-live-cand0`,
`nonexistent-sha`, and `sha-check-unset-empty`. They are not limits. For these cases only,
the runner derives a comparison from the frozen output by changing `aienos` to `aienux` in
complete `api repos/aien-dev/aienos/commits/<40-hex> -q .sha` and
`FAIL: commit <40-hex> not found in aien-dev/aienos` lines. Every other byte, including
exit status, ordering, SHA and other repository names, must match. The transformation must
actually change the oracle: refreshing it to the new name fails, as does reverting the
checker to the old name. Do not use `record` with the current checker to refresh the frozen
shell oracle. PR #326's six hand-edited outputs were restored from its parent `a211260`.

### Extension cases

The frozen counts above do not change when `check_pins` gains behaviour the bash never had. Such
behaviour is pinned by **extension cases**: 19 pins cases (`mv-*`, `intree-*`, `live-cand5`,
`live-cand5-intree`, DRA-46) whose directory holds an `extension` file saying what the case pins.
Their expected files were recorded from the .om with `run.sh <cc> <cp> record-extensions` (which
records extension cases only and still compares every frozen case) and reviewed line by line; a
plain `record` skips them. `run.sh` counts them on a second line, and any difference fails it:
`extensions: 19 identical, 0 different`. The pre-extension checker (cd68086) gets 16 of them wrong
(the three it passes, `mv-two-names-same`, `mv-prefix` and `intree-protocols-key`, pin behaviour
that did not change). `live-cand5` runs the frozen CAND-5 manifest on byte copies of its pinned lock
files (`scripts/testdata/cand5-locks/`: sovereign-core dffdbd19 `omega.lock` and `Cargo.lock`,
omega f9a9a40 `aienos.lock`, `physics.lock`, `argus.lock`, the same git blobs; both live cases link
their `files/` to it) and names exactly one
difference, spark-crumbs; `live-cand5-intree` adds `contracts.spark-crumbs-consumed = "in-tree"`
and agrees. `mkcases.sh` builds the extension cases too.

The suites `scripts/test_check_candidate.sh` (47 checks, 7 mutants) and
`scripts/test_check_candidate_pins.sh` (17 checks) compile the .om with `AIEN_OMC` and run it;
their counts are the same as against the bash. The mutants are now sed edits of the .om source
(`z = zero64 e`, `notq`, `NREQ`, `optpins`, `optpin`'s `shaex`, `mfeq`, `inmf`), recompiled.
Since DRA-46 the pins suite also has 12 checks of `-mv` sources and in-tree contracts and 5 mutants
(the `-mv` match, and in `itcheck`/`pathpkg` the git-source, path-package, source-line and word
checks), 34 in all.
`tests/gates/run.sh script-tests` refuses to run (exit 3, NOT_RUN) unless `AIEN_OMC` hashes as
`tools/zero-legacy/omega.pin` pins, then runs the parity corpus and the four suites.

## Limits (named differences from the bash)

1. **Locale.** The bash ran under the caller's `LANG`; in a UTF-8 locale its regexes refused a
   line holding invalid UTF-8 and counted any `iswspace` character (U+2003, U+3000, not U+00A0)
   as `[[:space:]]`. The .om matches bytes and knows the six ASCII spaces only, which is the
   bash's own behaviour under `LC_ALL=C`. Every real manifest is ASCII. Cases
   `non-ascii-invalid`, `non-ascii-space`.
2. **Amendment order.** The bash glob `<stem>.amendment-*.toml` sorted in the locale's
   collation (`en_US`: 10, 1, 2); the .om walks the names in byte order (1, 10, 2; the `LC_ALL=C`
   order). Only the order of FAIL lines when several amendments fail differs; the count, the
   checks and the exit code do not. Case `amend-order`.
3. **NUL warning.** When a fetched lock file holds a NUL byte, bash printed
   `warning: command substitution: ignored null byte in input` on stderr and went on; the .om
   drops the byte silently. Case `lock-nul`.
4. **Diagnostics of the shell itself** are not reproduced: an unreadable manifest (bash printed
   `Permission denied` and went on with no keys; the .om goes on with no keys silently), a
   `CAND_SHA_CHECK` command that does not exist (`sh: not found`, exit 127, versus bash's
   `command not found`, exit 127; both report `commit ... not found`), and glob characters in
   `CAND_SHA_CHECK` words (bash expanded them; the .om does not).
5. **Capacities** (exit 70 with a message, where bash had none): a manifest, amendment or fetched
   file over 999,000 bytes; more than 4096 keys in one file; a key or section name over 8191
   bytes; more than 1024 amendment files; more than 256 revisions of one package in a Cargo.lock;
   a child argument list over 4096 bytes; an environment entry over 65,536 bytes is not replayed.
6. **Binary lock files.** `grep` in a UTF-8 locale treats invalid UTF-8 as binary and prints
   `binary file matches` instead of the line; the .om reads the bytes. Not exercised by the corpus.
