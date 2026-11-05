# Security policy

## Reporting a vulnerability

Report privately. Do not open a public issue, pull request or discussion about it.

1. GitHub: open this repository's Security tab and choose "Report a vulnerability". This
   creates a private advisory that only the maintainers can see. If that option is not shown,
   private vulnerability reporting has not been enabled for this repository yet; use email.
2. Email: drake@aienos.com with the subject `[aien-architecture-mv] security report`.

Include the commit or release you tested, the component (path), steps to reproduce, and what an
attacker gains. If the report involves a secret, say where it was exposed and do not send the
secret itself. Encrypted mail is not required; do not post proof-of-concept payloads publicly.

## Response targets

This project has one maintainer; the targets below are best effort and stated honestly.

- Acknowledgement: within 3 working days.
- Triage and severity: within 7 days of acknowledgement.
- Fix or mitigation for confirmed issues: aim for 30 days for high and critical, 90 days
  otherwise, with a status update at least every 14 days until closed.
- Disclosure: coordinated. An advisory is published with credit (unless you ask otherwise)
  once the fix is on the default branch. Default embargo 90 days, negotiable.

## Scope

This repository is the architecture and status authority for AIEN: documents, plans, ADRs,
qualification candidate manifests, and a few checking tools. README: there is no product to build
here.

In scope:

- The crumb tool `tools/crumb/crumb.c` (C11), which reads `.crumb` files and coordination-store
  records, including hostile ones (`tools/crumb/test-hostile.sh`).
- The seeded Omega checkers in `tools/candidate/`, `tools/doctrine/` and `tools/zero-legacy/`
  accepting a manifest, pin or tree they should refuse.
- `scripts/pr-gate.sh`, which reads GitHub state and can squash-merge, and the other scripts.
- The tracked workflow `.github/workflows/aien-verification.yml`.
- A status claim in this repository that its cited receipt does not support.

Out of scope: the repositories whose design is described here; report those in their own
repository.

## Supported versions

Only the default branch `main`. There are no releases. Reports against older commits are welcome but fixes land on the default branch only.

## Status

README (2026-10-26): AienOS is in alpha testing; the rest of the stack is research-grade and
pre-alpha. Nothing in AIEN is described as qualified unless a receipt says so. No certification,
no bug bounty. See AUDIT_SCOPE.md for what to review and how to build and test it.
