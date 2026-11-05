# CUDA capability register checker (seeded `.om`)

Status: **IMPLEMENTED, EXERCISED on host (aarch64) by the `capreg` gate step.**

The register itself is [`docs/capability-register/register.tsv`](../../docs/capability-register/register.tsv)
(the source of truth) and its generated view [`REGISTER.md`](../../docs/capability-register/REGISTER.md).
It records, for every row of the 47-row CUDA replacement map in the 2026-10-27 external audit and for
work done since, which aien-dev repository owns the capability, at which exact commit, on which
architecture it was exercised, and which file proves it.

Both programs here are native Omega, built only by the pinned seed compiler named in
`../zero-legacy/omega.pin` (sha256 `734f0a39…6b61`). No C, Rust, Python or shell makes a judgment.

| File | Role |
| --- | --- |
| `capreg.om` | `capreg check REG`, `capreg render REG`, `capreg verify REG VIEW`, `capreg evidence REG CLONEROOT` |
| `gate.om` | the gate runner: checks the compiler against the pin with `../zero-legacy/sha256.om`, builds `capreg.om`, runs the fixtures, the register and a planted bad row, prints `AIEN-OBS` lines |
| `gate.sh` | the loader outside the programs: compile `gate.om` with `$AIEN_OMC` and exec it |
| `fixtures/` | `good.tsv` and its view `good.md`; 22 `bad-*.tsv` with the exact stderr each must produce in `bad-*.err` |

## Schema

`register.tsv` is UTF-8, one header line and one record per line, exactly 16 TAB-separated fields,
none empty (write `none` or `-`), no control byte other than TAB, no backtick, newline at the end.

| # | Field | Rule enforced by `capreg check` |
| --- | --- | --- |
| 1 | `row` | `NN.k`: NN is the audit map row 1..47, k counts owner components from 1; strictly ascending; every NN present |
| 2 | `area` | exactly the audit map name of row NN |
| 3 | `owner_repo` | `aien-dev/<name>` |
| 4 | `rev` | the exact commit, 40 lowercase hex |
| 5 | `ref_state` | `MERGED`, `DRAFT_PR#N`, `OPEN_PR#N` or `BRANCH:<name>` |
| 6 | `arch` | `host-aarch64`, `host-x86_64`, `GB10`, `QEMU`, `gpu:<name>` or `none` |
| 7 | `level` | `NONE_FOUND`, `PROPOSED`, `IMPLEMENTED`, `EXERCISED_HOST`, `EXERCISED_EMULATOR`, `EXERCISED_GB10`, `EXERCISED_OTHER_GPU`, `QUALIFIED_GB10` |
| 8 | `scope` | free text: what is covered (shapes, dtypes, ops) |
| 9 | `api_contract` | free text: the entry points or format |
| 10 | `test_command` | the command that produced the evidence; must not be `none` at an exercised or qualified level |
| 11 | `evidence` | `aien-dev/<repo>@<40-hex>:<path>` or `register:<path>` (relative to the register, no `..`) |
| 12 | `refusals` | what the component refuses or does not support |
| 13 | `deploy_state` | `NOT_DEPLOYED` or `DEPLOYED:<system>`; DEPLOYED needs `MERGED` |
| 14 | `audit_claim` | what the audit said, or `(post-audit)` for work it did not see |
| 15 | `audit_verdict` | `CONFIRMED`, `CORRECTED`, `OUTDATED`, `NEW` (exactly the `(post-audit)` rows) or `UNVERIFIED`; CORRECTED, OUTDATED and UNVERIFIED need a note |
| 16 | `note` | evidence for the verdict, or `-` |

Level and arch must agree, so no row can claim more than its evidence architecture:
`NONE_FOUND`, `PROPOSED`, `IMPLEMENTED` need `none`; `EXERCISED_HOST` needs `host-*` (a CPU
Vulkan or OpenCL driver such as lavapipe or PoCL is host); `EXERCISED_EMULATOR` needs `QEMU`;
`EXERCISED_GB10` and `QUALIFIED_GB10` need `GB10`; `EXERCISED_OTHER_GPU` needs `gpu:<name>`.
`NONE_FOUND` needs `register:absence/<file>` evidence: the log of the search that found nothing.
It is not proof of absence.

`check` judges form. Whether a cited file really exists at the cited commit is the separate
`capreg evidence REG CLONEROOT`, which runs `/usr/bin/git -C CLONEROOT/<repo> cat-file -e
<sha>:<path>` for every repository evidence (exit 3, NOT_RUN, when a clone is missing). It needs
network-fetched clones, so it is not part of the offline gate; its last run is recorded in
`docs/capability-register/evidence-check.log`.

## Use

```sh
omc=/path/to/pinned/omc                       # sha256 must match ../zero-legacy/omega.pin
mkdir -p build && "$omc" < capreg.om > build/capreg && chmod +x build/capreg
build/capreg check  ../../docs/capability-register/register.tsv
build/capreg render ../../docs/capability-register/register.tsv > ../../docs/capability-register/REGISTER.md
AIEN_OMC="$omc" ../../tests/gates/run.sh capreg
```

Exit codes: 0 pass; 1 the register (or view) fails a rule, one `FAIL line N: rule` per finding on
stderr; 3 NOT_RUN (evidence mode with a missing clone); 64 usage; 65 register unreadable or over
500000 bytes; 100 + code on a trap. Capacities: 1024 records, a 999000-byte view.

## Where the gate runs

`tests/gates/arch-capability-register.gate` says `requires: - host`: it needs the pinned AArch64 omc
of `../zero-legacy/omega.pin`. Without `AIEN_OMC`, `run.sh capreg` exits 3 (NOT_RUN).

- **Hosted CI, every PR and every push to main:** the `AIEN Pinned-omc Gates` job of
  `.github/workflows/aien-verification.yml` runs on an `ubuntu-24.04-arm` runner. It checks out the
  omega-mv commit named in `omega.pin`, births omc from seed-0 with `sh seed/omega-from-seed.sh`,
  refuses a compiler whose sha256 differs from `omc_sha256`, and runs `tests/gates/run.sh capreg`
  (with `doctrine`, `zero-legacy` and `script-tests`). A red or NOT_RUN step fails the job. Like the
  rest of that workflow it is advisory: main requires no status check.
- **The hosted AIEN Checks job** (x86) runs only `crumb verify` and the gates that require only
  `portable`, so it never runs this gate.
- **On the Spark:** `AIEN_OMC=<pinned omc> tests/gates/run.sh capreg`, and `aien-alpha
  aien-architecture <sha>`, which runs every gate. A hosted run is a run on GitHub's AArch64 runner,
  not a signed Spark receipt.
