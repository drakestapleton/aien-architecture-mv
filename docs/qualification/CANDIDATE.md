# Qualification candidate pinning (C2)

Status: spec, part of the AIEN Convergence Plan task C2.
Scope: how one exact integrated AIEN build is named, frozen, and judged.

## Why this exists

`CURRENT_EXECUTION_PLAN.md` line 45 says the R16 receipt binds candidate `850fc545`, that every candidate-bound R13 to R16 receipt predates omega `#126` (`4f8485b`), and that the current living build is IMPLEMENTED / NOT QUALIFIED until re-qualified. The same line records that omega `#112` merged with its `evidence-immutable` check failed. Both problems come from judging code that was not the code being shipped. A candidate manifest closes that gap.

## Reuse, no parallel format

Results are `EvidenceReceiptV1` receipts from `aien-sovereign-core/crates/aien-proof` (`src/evidence.rs`: fields `repo`, `commit`, `dirty`, `toolchain`, `procedure`, `machine`, `env_class`, `input_artifacts`, `output_artifacts`, `assertions`, `output_digest`, `result`). Formal proofs use the `formal-oracle-binding` receipt kind (`src/formal.rs`, `KIND`). This spec adds only the candidate manifest and the rules below. It does not define a new receipt. CAND-0 was frozen on 2026-10-05 and replaced the never-frozen 2026-10-01 draft of the same id.

## The candidate manifest

A candidate is a TOML file `qualification/candidates/CAND-<n>.toml`, schema `CandidateManifestV1`, with:

- `schema`, `id`, `status`, `created`.
- `[commits]`: one full 40-hex commit per repo: `omega`, `aienos`, `aien-sovereign-core` (FORGE and `aien-proof`), `aien-protocols`, `aien-architecture`. The contracts and wire schemas live in `aien-protocols`, so its pin is the contracts pin. The crumb contracts are pinned separately in `[contracts]`.
- `[executables]`: a content digest for every built binary or image under test. `UNBUILT` is allowed only while status begins with `draft`.
- `[contracts]`: one full 40-hex commit for each contract repo: `crumb-spec` (the Crumb Protocol specification) and `spark-crumbs` (its event ledger implementation). Orchestrator decision 2026-10-01: both are contracts and are pinned in every candidate. Both repos are archived on GitHub, so the pins are stable. When sovereign-core builds a contract crate from its own tree instead of consuming it from git (spark-crumbs since sovereign-core #892), the manifest states it with `[contracts] spark-crumbs-consumed = "in-tree"` (likewise `crumb-spec-consumed`); the 40-hex contract pin stays. `check_pins` then requires a path package of that name and no git source for it in sovereign-core's `Cargo.lock` (2026-11-07, DRA-46; for candidates after CAND-5, since a frozen manifest cannot gain the key).
- Optional `[commits]` keys `physics` and `interplane` (added for CAND-0): validated like the others when present. Informational sections the checker ignores: `[consumed_pins]` (pins the pinned repos themselves hold, so a mismatch with `[commits]` is visible), `[model]`, `[toolchain]`, `[build]`, `[env]`, `[hardware]`. A candidate may carry a companion `CAND-<n>.gates.md` next to its manifest with the build recipe, the reproducibility gaps and the required gate list (see `CAND-0.gates.md`); it defines no new format and no new receipt.

`status` is one of: `draft, not frozen`, `frozen`, `superseded`. Only a `frozen` candidate may be qualified.

## Freeze rules during a campaign

1. A campaign runs against exactly one frozen candidate. Any change to a pinned commit or executable digest creates a new candidate id; the old one is `superseded`, never edited.
2. Unrelated development continues on other branches and on `main`. Freezing pins commits; it does not lock repos.
3. A fix found by the campaign lands on main as usual, then a new candidate is cut and the affected results are rerun.
4. A frozen manifest is immutable. Edits to it are rejected, the same as evidence.

## Required fields on every result

Each result (a receipt, or the campaign table row pointing to one) carries:

| Field | Meaning | EvidenceReceiptV1 home |
|---|---|---|
| source commits | the candidate id and each pinned commit used (including `[contracts]`) | `repo`, `commit`, `dirty` (must be false); `external_refs` carries the candidate id as `cand:<id>` |
| executable digest | digest of the binary or image run; must equal the manifest `[executables]` entry | `external_refs`, one entry `exe:<name>=<digest>` per executable (kept apart from inputs; `input_artifacts` is a digest list with no role tag) |
| execution environment | host, QEMU, or physical GB10 | `env_class`, `machine` |
| inputs | data, models, seeds (never the executable) | `input_artifacts` |
| commands | exact procedure | `procedure`, `toolchain` |
| raw output location | where the full output is stored | `output_artifacts`, `output_digest` |
| acceptance criteria | the pass condition, written before the run | `assertions` |
| status | `PASS`, `FAIL`, `SKIPPED`, or `BLOCKED` | `result` |

A result with a missing field, a dirty tree, or a commit not in the manifest is not a PASS. `SKIPPED` and `BLOCKED` are never reported as PASS. `Verdict` in `evidence.rs` also has `INCOMPLETE` (the run did not finish or lacked a required field). Campaign tables report it as `INCOMPLETE`, never as `BLOCKED`: `BLOCKED` means something outside the run (hardware, access, a dependency) stopped it, `INCOMPLETE` means the result itself is missing evidence. Both are not-PASS.

## Old receipts

Receipts for earlier code stay valid history. They prove what they bound. They never qualify new code: a receipt counts toward a candidate only if its `commit` and executable digest match that candidate's manifest.

## Carry-forward of evidence by executable identity

"Old receipts" says a receipt never qualifies new code. One exception exists: an executable that did not change may carry its earlier result into a new candidate, under all of these rules. Precedent: `qualification/candidates/CAND-2.gates.md` section 2 ("Results carried from CAND-1 by executable identity (not rerun)").

1. Identity: the executable's SHA-256 in the new manifest `[executables]` equals the digest in the earlier frozen manifest. A digest that differs by one bit does not carry.
2. Inputs: every input the gate consumed is unchanged. That covers model inputs (sha256 in `[model]`), fixtures, and the test sources and flags listed in the gate's declaration. If a gate builds its own test binary, the new candidate shows that binary byte-identical to the earlier one, as CAND-2 did for `gpu_attention_test`.
3. Environment and labelling: the environment class (host build, QEMU, or silicon) is the same as the original run. The carried result is recorded with the earlier candidate id, the earlier receipt sha256, and the words "carried from CAND-N by executable identity (not rerun)". The receipt keeps naming the earlier candidate; it is not rewritten.
4. Gate definition: a result never carries across a change of the gate script, the harness, or the declared thresholds. A changed definition is a new gate and is rerun.
5. Status: `BLOCKED`, `NOT_RUN`, `FAIL` and `NOT_QUALIFIED` carry only as the same status. They are never upgraded by carrying, and a carried `PASS` does not clear a `BLOCKED` item.
6. Silicon performance: performance results measured on silicon (for example R15) do not carry. They are rerun on the new candidate.

A result that meets rules 1 to 6 is reported as carried, in its own table section, apart from results rerun on the candidate. A result that fails any rule is rerun.

## Promotion checks and exceptions

Promotion checks (for example `evidence-immutable`) are mandatory. A bypass needs a written exception under `qualification/exceptions/`, committed before or in the same change as the bypass. See `qualification/exceptions/0001-r16-immutability.md`.

## Checker

`tools/candidate/check_candidate.om` (seeded native Omega, #316; built with the pinned compiler, `tools/candidate/README.md`; it replaced `scripts/check_candidate.sh` with frozen-oracle parity subject to the documented limits and exact kernel-repository naming delta) run as `check_candidate <manifest.toml>` verifies that all required fields are present, that each pinned commit (`[commits]` and `[contracts]`) is 40 hex digits and exists in its repo (checked with `gh api`), that executable digests are 64 hex and not all zero, that a `#` inside a quoted value is kept (only a trailing comment is dropped), and that a non-draft manifest has real executable digests. The historical manifest key `commits.aienos` resolves to the Aienux kernel repository `aien-dev/aienux`, not the whole system. The whole system is Sovereign Intelligence (SI); AienOS is only the operating-system layer (ADR 0045). Test: `scripts/test_check_candidate.sh` (compiles the .om with `AIEN_OMC`; the 2026-10-01 draft is kept as `scripts/testdata/cand-draft-fixture.toml`; offline: a fake `gh` on PATH exercises the real `gh` code path, and mutant copies of the checker prove each check bites) and the frozen parity corpus `tools/candidate/parity/` (recorded from the bash checkers before their deletion; original output bytes are retained and the naming delta is checked separately). Locally the `ARCH-SCRIPT-TESTS` gate (`tests/gates/run.sh script-tests`) runs both; hosted CI wiring is not done and needs Drake's approval.

Amendments: a frozen manifest is not edited. Evidence recorded after the freeze goes in `<id>.amendment-<n>.toml` next to the manifest (schema `CandidateAmendmentV1`: `candidate`, `amendment`, `date`, `reason`, `manifest-sha256` = the sha256 of the frozen manifest file, then the added keys), with a dated note in `<id>.gates.md`. `check_candidate` reads every amendment with its manifest and refuses one that names another candidate or number, pins a manifest sha256 that is not the file's (so a later manifest edit fails), re-states a key the manifest already has, touches `[commits]`, `[contracts]`, `[executables]` or `[consumed_pins]`, or adds a `*-sha256` that is not a real digest. `check_pins` is unaffected, since an amendment cannot change pins. First use: CAND-4 Amendment 1 (oracle fixture digests, 2026-10-06).

`tools/candidate/check_pins.om` (seeded native Omega; it replaced `scripts/check_candidate_pins.sh` with byte-identical output, and since 2026-11-07 also reads `-mv` sources and in-tree contracts, pinned by extension cases of the parity corpus; `tools/candidate/README.md`) run as `check_pins <manifest.toml>` verifies that the pins agree with what the pinned code consumes: the sovereign-core `omega.lock` equals `[commits] omega`; the sovereign-core `Cargo.lock` git revisions of aien-protocols, crumb-spec and spark-crumbs (under the repo name or its `-mv` name, issue 815; both names are one pin) equal `[commits] aien-protocols` and the two `[contracts]`, or, for a contract stated `<name>-consumed = "in-tree"`, `Cargo.lock` holds a path package of that name and no git source for it; the omega `physics.lock` and `aienos.lock` equal `[commits] physics` and `aienos`; each known `[consumed_pins]` entry equals the value read. Lock files are read from GitHub at the pinned commits. A repo with two revisions in `Cargo.lock`, or an unreadable lock file, fails. Test: `scripts/test_check_candidate_pins.sh` (compiles the .om with `AIEN_OMC`; offline, lock files served by a stub) and the parity corpus. Results on the frozen manifests (2026-10-05): CAND-0 disagrees on aienos (its recorded gap G1); CAND-1 disagrees on both contracts: it pins the crumb-spec and spark-crumbs heads (`10b8251`, `98bb7cb`), while its sovereign-core `Cargo.lock` consumes `24194d1` and `9355a92`, the values CAND-0 pins. Frozen manifests are not edited; CAND-1.gates.md and later candidates record it. CAND-5 (2026-11-07, after the `-mv` and in-tree change): every pin agrees except spark-crumbs, which sovereign-core builds in-tree while CAND-5 pins the archived `9355a92` and cannot state the in-tree key (CAND-5.gates.md section 4).
