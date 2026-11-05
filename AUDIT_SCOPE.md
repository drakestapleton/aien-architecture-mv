# Audit scope

Written for an outside, independent security audit. Revision described:
`fabf7b765a29d1e9b7d45c5b52852ee39bbfad56` on `main`, 2026-10-26. Everything below is taken from the repository's own files at
that revision; items marked NOT_RUN were not executed while writing this document.

## What this repository is

The AIEN architecture authority (AGPL-3.0-or-later): `PLAN_AUTHORITY.md`,
`CURRENT_EXECUTION_PLAN.md`, `doctrine/` (architecture and milestone registry), `docs/` (ADRs,
plans, research, archive), `qualification/` (release candidate manifests and gate results),
`formal/invariants/` and `bootstrap/formal-oracles/lean/` (Lean models). Code that runs:

- `tools/crumb/` (`crumb.c`, 2,380 lines of C11, with `Makefile` and three test scripts).
- `tools/candidate/check_candidate.om`, `check_pins.om` and a parity oracle with 477 case files and 117 expected outputs.
- `tools/doctrine/doctrine.om`, `gate.om`; `tools/zero-legacy/closure.om`, `expect.om`,
  `gate.om`, `sha256.om`, with fixtures.
- `scripts/` shell tools and `scripts/pipeline-proofs/`.

## What an auditor can and cannot check here

- Can check: the crumb tool and its tests, the Omega checkers and their fixtures, the gate
  scripts, and whether each status line in `doctrine/ROADMAP.md` and `CURRENT_EXECUTION_PLAN.md`
  cites a receipt.
- Cannot check here: the receipts themselves, which live mostly in omega-mv `evidence/` and in
  aien-dev/aien-receipts; any hardware result.

## What to review, in priority order

1. `tools/crumb/crumb.c`: parsing of `.crumb` files and store records, path handling, the store
   identity refusal (exit 3) and refused store file (exit 4) paths.
2. `tools/candidate/check_candidate.om` and `check_pins.om`: they spawn processes (`gh api ...`,
   or the command in `CAND_SHA_CHECK` run as `$CAND_SHA_CHECK <repo> <sha>`); check how repository
   names and shas from a manifest reach those argument lists.
3. `tools/zero-legacy/gate.om` and `closure.om`: the closure checker; `gate.om` checks the omc pin
   with its own SHA-256 (`sha256.om`).
4. `scripts/pr-gate.sh`: merge gate with `--dry-run` and `--admin-authorized-by`; check what
   merges when a step is SKIP.
5. `tests/gates/run.sh` and `scripts/pipeline-proofs/18-crumb-only-no-rebuild.sh` (uses a
   persistent target cache under `XDG_CACHE_HOME`).
6. `.github/workflows/aien-verification.yml`: advisory AIEN Checks and the AIEN Alpha tag check.

## Trust boundaries

- Untrusted input to the tools: `.crumb` files and store records, candidate manifests and
  amendments, trees scanned by the zero-legacy checker, GitHub API responses.
- Trusted: the pinned seed compiler in `tools/zero-legacy/omega.pin`, `gh` and `git`, and
  `.aien/verify.pub` as the Alpha trust anchor.
- Workflow header: GitHub-hosted compute builds only the pinned verifier tools, never this
  repository's code.

## Threat model summary

- Assets: the honesty of the status of record; the integrity of qualification manifests and pins.
- Attackers considered: hostile store files (FIFOs, unbounded reads per `test-hostile.sh`), forged
  or zero digests in manifests, amendments that change frozen fields, legacy sources hidden in a
  tree.
- Defended: refusal exit codes in crumb, manifest rules in `docs/qualification/CANDIDATE.md`,
  byte-for-byte parity of the Omega checkers against recorded outputs, a watchdog and 1 GiB
  address-space limit in the hostile tests.
- Not defended / explicitly out of scope: the truth of receipts held elsewhere; GitHub account
  security. README: hosted checks are advisory and do not gate a merge.

## Build from source at a pin

The crumb tool needs a C11 compiler and `make`. The Omega tools need omc from omega-mv
`a0eafa39ac9a92786dac68f7aa6d8564a28fa981` with sha256
`734f0a39319fbfa930bcc62cb30dbf06d47d78e126372b74f5baf478e6126b61`
(`tools/zero-legacy/omega.pin`, built with `sh seed/omega-from-seed.sh`). The Lean models name
`leanprover/lean4:v4.34.1`.

```sh
make -C tools/crumb test
$AIEN_OMC < tools/candidate/check_candidate.om > check_candidate && chmod +x check_candidate
```

## Run every test

NOT_RUN while writing this document. From README and `tests/gates/run.sh`:

```sh
./tools/crumb/crumb verify .
bash tests/gates/run.sh crumb-verify
bash tests/gates/run.sh crumb-tool-test
bash tests/gates/run.sh script-tests
AIEN_OMC=<pinned omc> bash tests/gates/run.sh doctrine
AIEN_OMC=<pinned omc> bash tests/gates/run.sh zero-legacy
bash tests/gates/run.sh qualification-status     # needs an omega checkout at ../omega
bash tools/candidate/parity/run.sh <check_candidate-bin> <check_pins-bin>
bash scripts/pipeline-proofs/run-all.sh
```

`doctrine` and `zero-legacy` report NOT_RUN (exit 3) without the pinned compiler.

## Known limitations and NOT_RUN

- `tools/zero-legacy/README.md`: v0; release mode implemented and gate-tested on fixtures, not yet
  wired into any release decision.
- README: the Aienux kernel is not physically qualified; CAND-3 as a whole is not claimed
  qualified; CAND-4 has no R15 or R16 rerun.
- The crumb tool is C, outside the Omega rule; README describes it as the one program.
- `omega.pin` names an SSH clone URL (`git@github.com:...`); an outside auditor will use HTTPS.

## Dependencies and provenance

- Crumb tool: libc only (C11, `make`).
- Omega tools: the omc pin above. Lean models: `lakefile.toml` and `lean-toolchain`.
- Workflow: `aien-test` built from `aien-spark/aien-sovereign-core` at
  `a51042b61b87355c0850ef82ba409a46e153a1ff`; actions pinned by full commit sha (tag noted in a comment).

## Evidence

- `qualification/candidates/` (manifests and `*.gates.md` results) and `qualification/exceptions/`.
- `scripts/pipeline-proofs/RESULTS-2026-10-11.md`.
- `tools/candidate/parity/cases/` and `expected/`: recorded checker outputs.
- Run receipts cited from `CURRENT_EXECUTION_PLAN.md` and `doctrine/ROADMAP.md` live in other
  repositories.
