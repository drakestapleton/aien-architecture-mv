# AIEN Repository Execution Rules

## Adoption

Adopted 2026-10-10 from Drake's revised rules for the six-issue campaign (interplane#97 and #98, aien-sovereign-core#397 and #398, aegis-runtime#38 and #39). Tooling: `scripts/pr-gate.sh` and `scripts/rebase-crumb.sh`.

## Recorded facts (2026-10-10)

- (a) Branch protection read from GitHub: interplane requires the checks schemas-and-fixtures, rust, python, cross-language, adapter-aien and adapter-odysseus, in strict mode, with no review count. aien-sovereign-core requires the check "Workspace Verification & Invariant Audit", 0 reviews, enforce_admins on. aegis-runtime requires the check "Test & Invariant Verification", 0 reviews, enforce_admins on. Therefore `--admin` is never needed for a green PR.
- (b) interplane has no .crumb files, so the crumb step is skipped there with a notice. aegis-runtime and aien-sovereign-core use crumbs.
- (c) INTERPLANE carries a Python SDK by Drake's 2026-10-04 direction (approved exception). The Motus adapter for interplane#97 lives only under interplane adapters/motus. No Python enters any AIEN-owned repository.


These rules apply to Claude Code, all delegated workers, and all repositories involved in this implementation campaign.

The objective is to ship verified code without corrupting shared branches, bypassing security requirements, or creating unnecessary integration conflicts.

## 1. Source of Truth

GitHub main is authoritative. Inspect current code, tests, active PRs, and repository instructions before editing.

Never implement an issue solely from its description. Check whether the functionality already exists or has been superseded.

Use separate branches and worktrees for concurrent development.

One worker owns each writable worktree. Never allow two workers to modify the same worktree concurrently.

## 2. Crumb Compilation

Retired (DRA-97, 2026-11-07: "Retire Crumbs from the active workflow while preserving live ownership"). A PR needs no `crumb compile`, no `crumb verify` and no separate crumb commit; existing `.crumb` files stay as history. The rule as it stood:

Every applicable PR must have `.crumb` compilation and verification completed after its final source change.

Required commands: `crumb compile .` then `crumb verify .`

Commit generated `.crumb` changes separately as the final commit.

Do not modify source files after that commit without rerunning compilation and verification.

If a repository does not support these commands, report the discrepancy and follow its explicit repository policy. Never silently skip a required check.

## 2a. Local verification

`scripts/pr-gate.sh` reads GitHub's CLEAN state. It does not prove the commit was verified. The local admission check that complements CLEAN is `aien-test verify COMMIT` (sovereign-core `tools/aien-test`, ADR 0033 amendment 2026-10-11): it prints READY when every gate required at the base ref has a PASS receipt for that exact commit and the crumbs are CURRENT there, and BLOCKED otherwise, with the reason (a missing or NOT_RUN gate, STALE crumbs, an UNMAPPED changed path, or a BLOCKED_OPERATOR head). Run it on the final SHA, the one that includes the crumb commit (`docs/crumbs/LOCAL_PIPELINE.md` section 2); a pre-crumb SHA is never READY.

Trust anchors come from the base ref, never from the head under test (ADR 0033 amendment, A1): the required gate set, `.aien/verify.pub`, `.aien/always` and `.aien/unmapped-ok` are read from `origin/main`. A head that changes the pipeline's own configuration (`.aien/`, `tests/gates/`, `.github/workflows/`, `.forgejo/`, `tools/aien-test/`) is BLOCKED_OPERATOR: the operator runs its verification by hand and says so in the PR. Acceptance proofs for the crumb side of this rule (determinism, fixed point, staleness, claims, rebase, final SHA) are `scripts/pipeline-proofs/13-*.sh` to `21-*.sh`; measured numbers in `scripts/pipeline-proofs/RESULTS-2026-10-11.md`.

## 3. Rebase and Crumb Conflicts

Every sovereign-core merge to main can invalidate `.crumb` files in other open PRs.

After each sovereign-core merge, evaluate remaining PRs for drift.

Approved recovery script: `scripts/rebase-crumb.sh <worktree> <branch>` (this repository).

Before running it:

- Confirm the worktree has no uncommitted changes.
- Confirm the intended branch and remote.
- Inspect the script before first use.
- Preserve the expected remote head for force-with-lease protection.
- Ensure no other worker is writing to that branch.

The script takes main's `.crumb`, recompiles crumbs as the last commit, and pushes with lease.

If it reports CODE CONFLICT, stop automated rebasing for that branch. Resolve the source conflict before recompiling.

Never discard source changes to manufacture a clean rebase.

Do not rewrite another worker's branch without coordination.

## 4. Definition of CLEAN

A PR may merge only when all of the following hold:

- Working tree is clean.
- Changes are based on the intended current main.
- No unresolved merge conflicts.
- Required compilation and crumb verification pass.
- Required tests and CI checks pass.
- Required approvals are present and valid.
- GitHub reports a mergeable state.
- No outstanding blocking security findings.
- The final diff contains no unintended changes.
- The implementation satisfies the linked issue's acceptance criteria.

Do not equate GitHub's CLEAN merge-state label with complete verification.

## 5. Merge Procedure

Serialize merges into each repository's main branch.

Default command: `gh pr merge N -R aien-dev/<repo> --squash --delete-branch`

Only use `--admin` when explicitly authorized for that specific PR and when the required project governance permits it.

Never use administrative privileges to hide failing tests, missing approvals, security findings, or unresolved conflicts.

After every merge, refresh main and revalidate dependent or competing PRs.

## 6. GitHub PR Editing

The normal `gh pr edit` workflow is currently unreliable in this environment.

Use the API fallback: `gh api -X PATCH repos/aien-dev/<repo>/pulls/N -F body=@file`

Verify the returned response and fetch the PR afterward to confirm the update.

Do not assume an API operation succeeded merely because the command exited.

## 7. Language and Runtime Constraints

No Python or systemd may be introduced as part of this campaign.

Use Rust for AIEN-owned runtime, orchestration, adapters, and execution control.

Motus may run externally using its own dependencies, but the AIEN integration must communicate over an explicitly verified protocol boundary.

If a task requires Python inside an AIEN-owned repository, treat it as an architectural conflict. Redesign it or report the blocker before proceeding.

Existing Python files do not authorize adding more Python. Flag any conflict with the strict repository policy rather than silently ignoring it.

## 8. Command Hooks

A local Bash hook rejects certain command text containing accelerator or kernel-module related terms.

Do not embed source-file contents containing these terms into Bash commands or heredocs. Use the approved Write tool for file creation and editing.

Do not attempt to bypass restrictions on executing prohibited operations.

If an approved development command is incorrectly blocked, report the exact failure and use an authorized alternative.

## 9. Commits and Attribution

Use small, logically isolated commits.

Required commit trailers, when attribution accurately reflects the contributors:

`Co-authored-by: Drake Stapleton <drake@aienos.com>`
`Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`

Do not invent contributors or misrepresent authorship.

Required PR footer: 🤖 Generated with [Claude Code](https://claude.com/claude-code)

Every PR must reference its issue, describe its implementation, identify verification performed, and disclose limitations.

## 10. Worker Models and Verification

Use Sonnet for delegated implementation workers unless instructed otherwise.

Workers may inspect, implement, test, and propose solutions within their assigned ownership boundaries.

A worker's claim of completion is not verification.

The coordinating agent must independently inspect every worker's changes and verify relevant tests, security invariants, and actual GitHub state.

Do not accept unsupported claims about test passes, hardware performance, successful merges, or completed integrations.

Use an independent reviewer for security-sensitive changes.

## 11. Failure Handling

Do not repeatedly retry the same failing operation without identifying the cause.

On failure:

1. Capture the exact failure and affected commit.
2. Determine whether it is source-related, environmental, or caused by concurrent changes.
3. Apply the smallest justified correction.
4. Rerun the affected verification.
5. Escalate or isolate persistent blockers without destroying valid work.

Never force-push another worker's changes away.

Never turn off tests, security checks, or authorization rules merely to make a PR merge.

## 12. Communication

Use plain English when reporting to Drake. Do not use em dashes or en dashes.

Provide concise updates that identify completed work, active work, blockers, and next actions.

Do not confuse attempted operations with completed operations.

## 13. Final Delivery

Before declaring the campaign complete:

- Verify every merged PR against its issue.
- Check relevant cross-repository interfaces.
- Run integration tests.
- Confirm no unintended dependency or architecture changes.
- Report remaining failed, skipped, or unavailable verification.
- Confirm final GitHub issue and PR status.

A task is complete only when the implementation, verification, and required integration are finished.

## 14. Worker Instructions

Worker briefs live with each campaign; this document wins when they conflict.

Stable rules and validated scripts live in aien-architecture (`docs/REPOSITORY_EXECUTION_RULES.md`, `scripts/pr-gate.sh`, `scripts/rebase-crumb.sh`).

**Operating principle: Ship correct, verified code. Preserve other workers' changes. Protect main. Never trade correctness for apparent progress.**
