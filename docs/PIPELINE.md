# Verification and merge policy

## Current process (since 2026-10-24)

The [`AIEN` workflow](../.github/workflows/aien-verification.yml) separates two checks:

- **AIEN Checks** runs on pull requests and pushes to `main`. It runs the portable smoke gates declared at the base ref when the repository is enrolled (its crumb step is retired: Crumbs left the active workflow under DRA-97, 2026-11-07). This is advisory, not a merge requirement and not a signed Spark receipt check.
- **AIEN Alpha** runs only on `alpha/*` tag pushes. The tag must point to a commit on `main`; this job requires a full signed Spark bundle from [aien-receipts](https://github.com/aien-dev/aien-receipts/tree/main/aien-architecture), verified against trust anchors from `origin/main`. A green PR check does not qualify Alpha.

GitHub branch rules and classic protection currently require no status check for merges (checked 2026-10-26). The old requirement for `AIEN Verification` no longer applies. The local Spark judge can still produce signed bundles, but their presence is not implied by a PR check. A maintainer must review the diff and decide whether to merge; do not add `ready-to-merge` on the strength of an advisory check.

`scripts/pr-gate.sh` is a separate operator-invoked merge helper. Its merge command binds the reviewed PR head SHA using `--match-head-commit`; a head change requires restarting inspection. It is not the hosted Alpha gate and does not grant authority to merge.

## Historical process (2026-10-16 to 2026-10-23)

The Spark worker (`aien-test worker --github` in aien-sovereign-core) ran selected gates and `.aien/always` for a PR head, signed a bundle, and published status `AIEN Verification (Spark)`. The local pipeline checked the bundle against the base-ref public key and published it at `aien-architecture/<sha>/bundle.json` in aien-receipts. It reran a hosted `AIEN Verification` workflow to download and verify the bundle. At that time `main` required that hosted check and the local pipeline used the `ready-to-merge` label to promote approved heads. This describes the former policy, **not** what the current workflow does.
