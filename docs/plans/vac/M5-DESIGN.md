# VAC M5: bounded RSI hookup, design note (IMPLEMENTED, 2026-10-08)

Status: IMPLEMENTED 2026-10-08 (see "Outcome" at the end). The design text below is kept as written; where the build differs, the Outcome section wins. Original status line: PROPOSED, nothing implemented. Every claim about current code cites spark-rsi
`origin/main` e5aab9a, interplane `origin/main` 04a05dc, or aien-protocols `origin/main`, read on
2026-10-08. Build work starts only after M4 (clean-clone reproducibility) is qualified, per the
directive's Phase 5 rule.

## Goal, one sentence

spark-rsi proposes one Tier1 change to a pinned fixture repository; an evaluator it cannot control
scores the change on a holdout it cannot read or write; the change lands only through the existing
approved path (INTERPLANE -> ComposeApprovedProposal -> daemon ledger); the offline verifier refuses
the bundle unless a signed evaluation receipt names the exact bytes the ledger says were written and
the score meets a threshold fixed before the run.

## What the code already gives me

- **Proposal shape.** `ImprovementProposal` carries one `target_file` and a `proposed_patch`
  (spark-rsi src/models.rs:37). That maps onto one `write_file` effect, the only effect kind the
  daemon has.
- **Branch-only ratifier.** The ratifier creates `rsi/<id>` plus a patch file and never commits to the
  default branch (src/ratify.rs:14-20). This satisfies M5 done-condition (d) as it stands.
- **Fail-closed judge.** `BlindJudge::evaluate_cycle` refuses to run without a signing key or a
  non-empty holdout directory (src/actor/judge.rs:207-214; an empty holdout directory is refused in `HoldoutSuite::load_from_dir`, judge.rs:117-145). The judge also ships as its own binary
  that reads its key from a file (judge.rs:49, :641, :674).
- **Signed receipt.** `EvaluationReceipt` is signed with P-256 over `receipt_digest`
  (src/evaluator/mod.rs:96-100). `verify_signature` recomputes the digest before checking the
  signature (mod.rs:103-123).
- **Tier boundaries.** Tier2 engine changes may not touch `tests`, `src/evaluator`, `src/isolation`,
  `src/ledger`, `.rsi/holdouts`, `CONSTITUTION.md`, `LICENSE` (src/meta/tier.rs:34-42).

## Gaps found (must close before M5 can pass)

| id | gap | evidence | consequence |
|---|---|---|---|
| R1 | The signed receipt digest covers `cycle_id`, `candidate_id`, `parent_id`, `admitted` and the layer results only. It does not cover the candidate's content digest, the holdout set digest or the evaluator version. | evaluator/mod.rs:48-68 | A valid receipt can be paired with different patch bytes. Done-condition (c) cannot be checked from the receipt alone. |
| R2 | In the daemon, the judge's signing key is read from `signing_key_hex` in the RSI config, inside the same process that proposes. The signature label says `tpm2-p256` but the key is a software key. | daemon.rs:54-61, evaluator/mod.rs:100 | The proposer can sign its own scores. This breaks the directive's rule that RSI has no authority over its own verification. |
| R3 | The promotion safety envelope runs with an empty probe (`|| async { Ok(()) }`) and a policy digest hashed from a label built from `config.canary_target`, not from a policy file. | daemon.rs:467-504 | The envelope adds a signature, not evidence. |
| R4 | Promotion swaps RSI's own active generation (`atomic_symlink_swap`) and records it in RSI's own ledger. | daemon.rs:529 | A second effect path beside the daemon ledger. VAC must not use it for the M5 effect. |
| R5 | The VAC task record (`vac-task`) names `task_id`, `repo_commit` and `test_cmd` but not which file may change. The verifier ties the write path to the source pin, not to the task. | interplane provenance/src/testrun.rs:104-130; a retained `task.json` from the M3b slice | A run that edits the test file instead of the code still verifies. This also blocks M5 done-condition (f). Fix lands before M5 as its own verifier change. |

## Proposed design

1. **Objective.** The M3b fixture `fix_the_test` (or a second pinned fixture with a measurable
   objective) with a written objective: holdout pass count, and for a performance task a stated
   metric and unit. The threshold is fixed in a policy file committed before the run; its sha256 goes
   in the bundle.
2. **Holdout.** Lives outside the target repository and outside RSI's writable roots, owned by a
   different OS user or a read-only mount. RSI receives only the judge's verdict, never the holdout
   bytes. The holdout set digest is recorded.
3. **Judge.** The standalone judge binary, run as a separate process with its key file readable only
   by the judge's user (closes R2 for this lane). Its public key is pinned in the verifier's trust
   input, supplied by the operator, not read from the bundle.
4. **Receipt binding (closes R1).** A receipt version 2 whose digest also covers `subject_sha256`
   (the exact bytes proposed), `holdout_set_sha256`, `policy_sha256` and `evaluator_version`. Version
   1 receipts stay verifiable but cannot satisfy M5. This changes a signed format in spark-rsi, so
   it needs Drake's approval before merge (directive: no unapproved schema or security changes).
5. **Effect.** The winning candidate goes to INTERPLANE as a `write_file` proposal on the fixture
   repository and through ComposeApprovedProposal with the normal operator approval. RSI's
   `atomic_symlink_swap` and the R3 envelope are not used in this lane (R4).
6. **Verifier.** A new optional bundle section `evaluation`, binding `rsi-eval/2`: the verifier checks
   the P-256 signature against the operator-pinned key, `subject_sha256` equals the grant's
   `content_sha256`, `policy_sha256` equals the retained policy file, and the score meets the
   policy's threshold. New refusal codes: `evaluation_missing`, `evaluation_signature_bad`,
   `evaluation_subject_mismatch`, `evaluation_below_threshold`.
7. **Rollback.** A second approved `write_file` that restores the source pin's bytes, with its own
   ledger records; the rollback test checks the file digest equals the pinned prior digest.
8. **Negative tests.** (a) RSI proposes a change to a holdout or policy file: refused before any
   proposal reaches the daemon, and the verifier refuses a bundle that writes outside the task's
   target (needs R5). (b) A receipt for different bytes: `evaluation_subject_mismatch`. (c) A receipt
   signed by RSI's own key: `evaluation_signature_bad`.

## Decision needed from Drake before build

Receipt version 2 (item 4) changes what spark-rsi signs. It is additive (version 1 still verifies),
but it is a signed-format change and needs an explicit yes. Everything else in this note uses
existing paths.

Decided: Drake approved Option 1 (receipt version 2) on 2026-10-08 with six conditions: sign the candidate SHA-256, holdout digest, policy digest, evaluator version and results; the evaluated digest must match the authorized change and the bytes on disk; version 1 stays verifiable for history but never suffices for new promotions; the judge key stays out of the proposer's reach; missing, corrupt or incomplete holdouts are refused; negative tests for substituted changes and scores, altered policies, wrong keys and incomplete holdouts. Also: commit spark-rsi `Cargo.lock`.

## Done conditions

Unchanged from PLAN.md section D, row M5, items (a) to (f).

## Addendum, 2026-10-08: feasibility probe and three more gaps

Probe (spark-rsi `origin/main` e5aab9a, release build, no lock file): `spark-rsi-judge` ran with a
throwaway key file, two holdout suites copied from the built-in cases, and the engine as both parent
and candidate. It produced a signed receipt (`tpm2-p256:` label, software key) with
`admitted: false` (the candidate equals the parent, so nothing improved). Bubblewrap 0.9.0 is
present, so the jail runs on this host. `spark-rsi propose <path>` is a deterministic unslop scan
(src/main.rs:277-287) that prints one `ImprovementProposal`; it needs no model server.

| id | gap | evidence | consequence |
|---|---|---|---|
| R6 | The judge evaluates a candidate **executable**: each holdout case runs `<candidate> holdout <input>` in the jail and compares stdout (src/actor/judge.rs:220-247). The correctness layer runs `cargo check` and `cargo test` only (src/evaluator/layers/correctness.rs:112, :153). | probe; code | The C fixture `fix_the_test` cannot be judged. M5 needs a small Rust fixture whose binary answers `holdout <input>`. |
| R7 | `HoldoutSuite::load_from_dir` skips any file that does not parse and continues if one suite remains (judge.rs:117-145). | code | A corrupted or removed holdout file shrinks the holdout silently; with R1 the receipt does not show it. |
| R8 | spark-rsi has no committed `Cargo.lock`; `cargo build --locked` refuses. | probe | Builds of the judge are not pinned, so a receipt's evaluator cannot be rebuilt bit for bit. |

Recommended M5 slice shape (session decision, recorded): a new Rust fixture with one user-facing
file containing banned dashes and a `holdout` subcommand; `spark-rsi propose` yields the change;
the standalone judge, run as its own process with its own key file and a holdout directory outside
both repositories, signs the receipt; the change lands through the approved path as in M3b. RSI does
not target its own repository in M5, because that puts the evaluator's own files in reach.

How the verifier treats the receipt depends on the open decision (receipt version 2). With a yes, the
verifier requires `subject_sha256` to equal the grant's content digest. With a no, a version 1 receipt
can only be checked for signature and threshold, and the verdict must carry the label
`missing=link:evaluation_subject`.

## Outcome, 2026-10-08 (IMPLEMENTED)

Merged: spark-rsi#34 (merge commit 24f412f699f1942861fac5afb632cc8deda31ad1) and interplane#89 (merge commit
dc37ca3e5948945bf4619c015b6c817a0c0920a0). Final gate `adapters/aien/scripts/test-m5-rsi.sh` PASS on
interplane 0c8a92d and spark-rsi 4becebb, 2026-10-08 23:24Z; evidence in interplane
`adapters/aien/evidence/m5-rsi-2026-10-08/`.

The six conditions, as built:
1. Signed fields: receipt version 2 (spark-rsi `docs/RECEIPT-V2.md`) signs subject path and SHA-256, parent
   commit, holdout-set digest, policy digest, evaluator version and binary digest, layer results and holdout
   counts (P-256, the judge account's key).
2. Identity match: the harness precheck and the offline verifier require the receipt subject to equal the
   ledger grant's content digest and the ack's on-disk digest (`evaluation_subject_mismatch`), and the
   receipt parent to equal the bundle's source pin (`evaluation_parent_mismatch`). spark-rsi's promotion
   gate re-reads the promoted bytes before its swap.
3. Version 1: verifiable as history; `evaluation_v1_insufficient` in the verifier, refused by the
   promotion gate.
4. Key separation: judge key in `/var/lib/aien-judge` (mode 700), unreadable by the proposer account
   (setup script proves "Permission denied"). Everything the judge does with candidate source (build,
   `cargo check`, `cargo test`) runs in one bubblewrap sandbox without the judge's home, environment or
   network; the holdout jail has no network fallback.
5. Holdouts: the judge refuses a missing, empty, corrupt, incomplete or extra-file holdout set and any
   set whose digest differs from the policy pin.
6. Negatives (all in the gate, each with its named refusal): substituted score (two), edited subject,
   altered policy, wrong pinned key, dropped evaluation, substituted change, receipt signed by another key,
   version 1 receipt, other policy, re-signed low-bar policy pair against the operator pin, missing,
   corrupt, shrunk and stray-file holdouts, RSI aimed at another file, dirty workspace, workspace without
   its own repository.
`Cargo.lock`: committed in spark-rsi and enforced in CI with `--locked`.

Review: three independent reviews (separate sessions). Two blockers in the first (promotion did not check
the staged bytes; a prebuilt binary could be run) and one in the second (the correctness check ran
candidate build scripts outside the sandbox, which could have read the key) were fixed and re-tested
before merge; the third found no blockers and four smaller items, all fixed.

Differences from the plan: the gate script is `test-m5-rsi.sh` (PLAN.md named `test-rsi-hookup.sh`);
promotion goes through INTERPLANE's approved path, not spark-rsi's ratifier, so ratify is not exercised
and spark-rsi's own daemon refuses self-promotion (it only holds version 1 receipts).

Limits (also in the gate receipt): the operator account can read the judge key through sudo; the holdouts
are public, pinned by digest, not secret; the proposer is a rule-based scan, not a model, so the verdict
stays `PASS_LABELLED_INCOMPLETE missing=link:model_turn`; the speed allowance is 200% because timing this
microsecond fixture varied up to 79% between identical builds; the desk MAC stays default-off.
