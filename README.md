# AIEN Architecture

The authority for how the AIEN project fits together: whole-system architecture, milestone status and what to do next. It holds documents and a few small checking tools, not product code.

AIEN is a sovereign computing stack (one its owner builds, runs and controls end to end) being built in the open on an NVIDIA DGX Spark (Grace Blackwell GB10): its own operating system kernel (Aienux), its own reaction runtime and compiler (Omega), and its own machine realization layer (FORGE). Founding principle: closest to the metal, fastest wins. Build what is missing.

The whole system is Sovereign Intelligence (SI). AienOS is only the operating-system layer; Aienux is its kernel. [aien-dev/aienix](https://github.com/aien-dev/aienix) is retired. [sovereign-intelligence](https://github.com/aien-dev/sovereign-intelligence) is the integration, release and install center, and the place where the signed Spark test runs ([ADR 0045](docs/adr/0045-aienix-retired-sovereign-intelligence-center.md)). This repository is where the design decisions and the status of record are kept.

**Status 2026-10-26: AienOS is in alpha testing; the rest of the stack is research-grade and pre-alpha.** Alpha testers install one bundle: the Core engine built from aien-sovereign-core-mv `main`, the Omega install wizard and compiler (omc), and the CUDApp user-space replacement. Its GPU path runs only on the DGX Spark (GB10), and the three-run physical qualification has not been run. Everything outside that bundle, including the Aienux kernel, is pre-alpha. Nothing in AIEN is described as qualified unless a receipt says so. Details follow.

**Note 2026-10-30:** ADR 0045 names the whole system Sovereign Intelligence (SI); AienOS is now only the operating-system layer. In the 2026-10-26 status above, 'AienOS' meant the whole system.

## Human-Directed Agentic Engineering

Development follows Human-Directed Agentic Engineering (HDAE): humans define goals, architecture, constraints, acceptance criteria and stopping points; agents implement, execute checks, diagnose failures and revise within those boundaries. Human review retains responsibility for claims, acceptance and release decisions. The existing plan authority, milestone registry and qualification requirements remain unchanged.

For the documented method and systems-software case study, see Gregory M. Kurtzer, *Ginux: Building an Independent Kernel That Runs Linux Userspace through Human-Directed Agentic Engineering* (2026), [doi:10.5281/zenodo.23682548](https://doi.org/10.5281/zenodo.23682548). This is a description of the current development method, not a retrospective change to historical experiments or receipts.

## Current state

Alpha testing for the bundle above; research-grade and pre-alpha for everything else. The live numbers are not repeated in this file because they change daily; read [CURRENT_EXECUTION_PLAN.md](CURRENT_EXECUTION_PLAN.md) and [doctrine/ROADMAP.md](doctrine/ROADMAP.md). What follows is a summary, with the source for each point.

- **Aienux kernel.** The C kernel passes its emulator (QEMU) gates but is not physically qualified, and it has not been booted on the DGX Spark. Only an earlier first-boot test of the previous Rust kernel ran there, on 2026-09-24 (see the [Aienux README](https://github.com/aien-dev/aienux#readme)). Its first runs on real hardware were on a Raspberry Pi 5 on 2026-10-13 (same README). An x86_64 build of it starts on a 2017 Intel iMac used as a test computer ([aienux#405](https://github.com/aien-dev/aienux/pull/405), merged 2026-10-17, and the follow-up pull requests #406 to #408). The Aienux README does not yet describe the iMac runs.
- **Omega runtime, R1 to R16 ladder.** The ladder was first qualified on builds that predate the composition modules now in the living build. Requalification at omega `3108fc2` recorded R15 FAIL (14 of 16 gates) and R16 FAIL (omega [`evidence/REQUAL-3108fc2/`](https://github.com/aien-dev/omega-mv/tree/main/evidence/REQUAL-3108fc2)). The ladder was rerun on candidate CAND-3 (omega `f816473`): R16 gates G1 to G8 PASS, and R15 passed 16 of 16 gates as a conditional pass, because Secure Boot was off for that run ([CAND-3 results](qualification/candidates/CAND-3.gates.md), [exception 0002](qualification/exceptions/0002-r15-secure-boot-off.md)). CAND-3 as a whole is not claimed qualified, and CAND-4 has no R15 or R16 rerun ([CAND-4 results](qualification/candidates/CAND-4.gates.md)). The R15 and R16 rows in [doctrine/ROADMAP.md](doctrine/ROADMAP.md) still carry the earlier wording (they stop at CAND-0 and CAND-1).
- **ARGUS** (the defensive plane, which watches for attacks and proposes responses but never authorizes them). ARGUS-0, its event substrate, is complete under documented limits and ARGUS-1 containment is in progress ([ADR 0017](docs/adr/0017-argus-defensive-plane.md)).
- **Specifications only.** Physics Zero, DIRAC-0, the Evolution Arena and the necessary-work programme are documents or plans with no qualified code (see [Specifications and plans](#specifications-and-plans-not-qualified-code) below).

## Start here

Read in this order:

1. [Plan authority](PLAN_AUTHORITY.md): which document wins
2. [Current execution plan](CURRENT_EXECUTION_PLAN.md): the one active cross-project plan, with receipts
3. [Canonical architecture](doctrine/ARCHITECTURE.md): what the system is and who owns what
4. [Canonical milestone registry](doctrine/ROADMAP.md): milestone IDs and status
5. [Architecture decision records](docs/adr/README.md)
6. [Implementation status snapshot](docs/02-implementation-status.md) and [repository map](docs/01-github-repository-map.md)
7. [Golden path](docs/13-golden-path.md)
8. [Seed lineage](docs/SEED_LINEAGE.md): every running artifact, what builds it today, and which rung of the seed chain could birth it

Superseded plans are kept only under [docs/archive/plans](docs/archive/plans/README.md). If two documents disagree, do not write another master plan: record the discrepancy and fix the authority. Code and reproducible evidence beat any plan.

## What is in this repository

| Path | What it holds |
| :--- | :--- |
| `PLAN_AUTHORITY.md`, `CURRENT_EXECUTION_PLAN.md` | Which plan wins, and the one active plan |
| `doctrine/` | The canonical architecture and the milestone registry |
| `docs/adr/` | Architecture decision records (45 on `main`, listed in the [index](docs/adr/README.md)) |
| `docs/plans/` | Finite workstream plans (not master plans) |
| `docs/research/` | Research notes, for example the [repository layout note](docs/research/repo-topology-unix-vs-monorepo-vs-hybrid.md) and the [Hermes Agent note](docs/research/hermes-agent-prior-art.md) |
| [Aienet collaborator directory](docs/research/aienet-collaborators.md) | Prospective academic and community contacts, sources, collaboration questions, and SI-agent outreach rules; not an affiliation or enrollment list |
| `docs/archive/` | Superseded plans, kept for history only |
| `qualification/` | Release candidates (`candidates/CAND-*.toml` and their gate results) and recorded exceptions |
| `formal/invariants/` | Invariants written down for formal checking ([ADR 0027](docs/adr/0027-formal-oracle-lean-bootstrap.md)) |
| `docs/capability-register/` | The org-wide CUDA capability register: [register.tsv](docs/capability-register/register.tsv) (source of truth; owner, commit, arch, level and evidence file for each of the 47 rows of the CUDA replacement map) and its generated view [REGISTER.md](docs/capability-register/REGISTER.md) |
| `tools/capreg/` | The register checker and renderer in seeded `.om`, and its gate (step `capreg`) |
| `tools/crumb/` | The crumb tool (C11), which compiles and checks the `.crumb` files |
| `tools/ops/` | The Spark's shared measurement base: build once, one measurement window at a time, per-window calibration and 27B baseline ([how to use it](docs/ops/MEASUREMENT_WINDOWS.md)) |
| `scripts/` | Small shell tools (doctrine check, candidate and pin checks, R16 status wording, the pull request gate, crumb rebase helper) and their `test_*.sh` tests |
| `tests/gates/` | The gate manifests the Spark runs on every pull request |

`AIEN_COMPLETE_SYSTEM_ARCHITECTURE.md` and `AIEN_MASTER_ARCHITECTURAL_PLAN.md` at the root are superseded pointers; the old versions are in `docs/archive/plans/`. The second one is stored in Git as a symbolic link whose target is the pointer text, so it does not open as a normal file; read [docs/archive/plans](docs/archive/plans/README.md) instead.

## How the repositories fit together

```text
ATLAS AWAKENS.  ALLEN INTENDS.  AIEN PROPOSES.  OMEGA DEFINES.  FORGE REALIZES.
AEGIS VERIFIES.  HARDWARE ACTS.  EVIDENCE TEACHES.
```

| Repository | Role |
| :--- | :--- |
| [aienux](https://github.com/aien-dev/aienux) | Aienux, the kernel of AienOS, intended to replace the Linux kernel on the DGX Spark |
| [omega-mv](https://github.com/aien-dev/omega-mv) | The C reaction runtime and compiler that defines computation, and the native GB10 GPU engine |
| [physics-mv](https://github.com/aien-dev/physics-mv) | FORGE machine realization, plus historical Atlas/PHYSICS boot evidence |
| [aien-protocols-mv](https://github.com/aien-dev/aien-protocols-mv) | Versioned wire and state specifications |
| [aien-sovereign-core-mv](https://github.com/aien-dev/aien-sovereign-core-mv) | The Rust host runtime on Linux (the `aien` command line, inference ABI, KV cache, scheduler) and the verification pipeline that judges every repository; Rust here is scaffolding that Omega replaces piece by piece (ADR 0024) |
| aien-architecture-mv (this repository) | Architecture, decision records, milestone status and the execution plan |

These six keep their own parts and still live in separate repositories. [sovereign-intelligence](https://github.com/aien-dev/sovereign-intelligence) is the integration, release and install center, and the place where the signed Spark test runs; [aien-dev/aienix](https://github.com/aien-dev/aienix) is retired ([ADR 0045](docs/adr/0045-aienix-retired-sovereign-intelligence-center.md)). The research note on the layout is in [docs/research](docs/research/repo-topology-unix-vs-monorepo-vs-hybrid.md). Signed test results for all of them are published to [aien-receipts](https://github.com/aien-dev/aien-receipts). Historical `PHYSICS_*` milestone names stay unchanged in old milestones and evidence. Older documents link to `aien-spark/<name>` or `aien-dev/<name>`; those addresses are the same repositories under earlier names.

## Standing rules

- Language rule: Rust is scaffolding, Omega is the destination, C only where hardware-justified ([ADR 0024](docs/adr/0024-rust-scaffolding-omega-destination.md), which supersedes the old [Rust-to-C plan](docs/plans/RUST_TO_C_MIGRATION.md)).
- No Python, no CUDA toolkit, no systemd, no outside dependencies in the trusted base, offline builds.
- Verdict words: PASS, FAIL, NOT_RUN, BLOCKED_HARDWARE, BLOCKED_OPERATOR, MISSING_IMPLEMENTATION. Emulator, host simulation and documents never count as hardware qualification.

## Specifications and plans (not qualified code)

The [Physics Zero Atlas](docs/plans/physics-zero/PHYSICS_ZERO_LAW_ATLAS_V1.md), [DIRAC-0](docs/adr/0023-dirac-0-program.md) and the [Evolution Arena spec V1](docs/specs/EVOLUTION_ARENA_SPEC_V1.md) are documents. Finite workstream plans under `docs/plans/` must be marked NOT A MASTER PLAN ([PLAN_AUTHORITY.md](PLAN_AUTHORITY.md)); most are, but the `physics-zero` and `adaptive-intelligence` folders do not carry the marker yet.

The [necessary-work programme](docs/plans/necessary-work/README.md) (2026-10-18, PROPOSED) asks which work is unnecessary before making the chip faster; its feasibility research is [docs/research/necessary-work-program-feasibility.md](docs/research/necessary-work-program-feasibility.md). None of its experiments has run.

## Building and testing

There is no product to build here. The one program is the crumb tool in `tools/crumb`. It needs only a C11 compiler and `make`. Build it, run its tests, and check that every `.crumb` file matches what the tool produces now:

```sh
make -C tools/crumb test
./tools/crumb/crumb verify .
```

The Spark runs five gates on every pull request. Each manifest in `tests/gates/` calls `tests/gates/run.sh` with one step word, so you can run the same steps yourself (the script needs `bash`; plain `sh` stops at `set -o pipefail`):

```sh
bash tests/gates/run.sh crumb-verify          # gate CRUMB-VERIFY: the crumbs are current
bash tests/gates/run.sh crumb-tool-test       # gate ARCH-CRUMB-TOOL-TEST: the crumb tool tests
AIEN_OMC=<pinned omc> bash tests/gates/run.sh script-tests   # gate ARCH-SCRIPT-TESTS: the four checked scripts, the candidate checkers, and the workflow action-pin check (tools/workflow-pins/actpins.om; NOT_RUN without the pinned compiler)
AIEN_OMC=<pinned omc> bash tests/gates/run.sh doctrine   # gate ARCH-DOCTRINE: doctrine consistency (tools/doctrine, seeded .om; NOT_RUN without the pinned compiler)
bash tests/gates/run.sh qualification-status  # gate ARCH-QUALIFICATION-STATUS: R16 status wording
```

`qualification-status` reads omega evidence, so it needs an omega checkout beside this one at `../omega`.

For a Cargo repository, `CRUMB="$PWD/tools/crumb/crumb" bash scripts/pipeline-proofs/18-crumb-only-no-rebuild.sh <repo>` checks that a `.crumb`-only commit does not rebuild crates. It uses a persistent target cache at `${XDG_CACHE_HOME:-$HOME/.cache}/aien/pipeline/target-cold`, outside the temporary clone; set `TARGET_DIR` to reuse a different cache. The proof never deletes that cache. `CARGO_ARGS` defaults to `--locked --offline`.

## How a pull request is judged

Since the 2026-10-24 merge-policy change, GitHub-hosted **AIEN Checks** on pull requests and `main` are advisory: they run `crumb verify` and, for enrolled repositories, portable smoke gates. They do not download a signed Spark bundle or gate a merge. The **AIEN Alpha** job runs only on `alpha/*` tags, requiring a signed full Spark bundle for a tagged commit on `main`. See [docs/PIPELINE.md](docs/PIPELINE.md) for the current flow and the older process.

The crumb tool on `main` can now compute the generated part of each `.crumb` file on demand instead of storing it (RFC-0003 amendment 1, pull request #271, merged 2026-10-18; [docs/CRUMB_PROTOCOL_RFC_0003.md](docs/CRUMB_PROTOCOL_RFC_0003.md)). This repository switched on 2026-10-19 (pull request #272): its `.crumb` files no longer store that data, and `crumb verify .` computes it when it checks.

## Where the evidence lives

- Release candidates and their gate results: [qualification/candidates](qualification/candidates) and [qualification/exceptions](qualification/exceptions).
- Receipts for runs: in the repository that ran them, mostly omega [`evidence/`](https://github.com/aien-dev/omega-mv/tree/main/evidence), cited from [CURRENT_EXECUTION_PLAN.md](CURRENT_EXECUTION_PLAN.md) and [doctrine/ROADMAP.md](doctrine/ROADMAP.md).
- Signed Spark bundles, when produced: [aien-receipts](https://github.com/aien-dev/aien-receipts). Their absence on an ordinary PR is not a hosted-check failure.

## Contributing

Open a pull request against `main` with docs-only or doctrine changes, cite the receipt or code you are relying on, and state any outside review you obtained. Hosted PR checks are advisory, not a signed Spark qualification or permission to merge; do not add the `ready-to-merge` label without the maintainer's approval. Questions and design ideas are welcome as issues. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Licensed under the GNU Affero General Public License v3.0 or later (AGPL-3.0-or-later). See [LICENSE](LICENSE) and [LICENSE-NOTICE.md](LICENSE-NOTICE.md). Contact: aien@aienos.com.
