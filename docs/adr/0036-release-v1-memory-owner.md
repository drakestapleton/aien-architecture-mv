# ADR 0036: Release v1 memory owner (lane L3 of the release-readiness program)

**Status:** ACCEPTED (2026-10-10, engineering decision by the coordinating session under Drake's directive of 2026-10-10 to repair persistent memory recall without expanding the architecture; Drake's calls are collected on aien-architecture#190 and may amend this).
**Author:** Claude (Fable 5.1) for Drake Stapleton. Tracking: aien-architecture#197 (L3), aien-sovereign-core#386 (finding).
**Supersedes:** nothing. **Related:** ADR 0022 (memory owner at the Omega layer, rx_cortex), ADR 0035 (Aien as the durable subject), `docs/plans/release-readiness/GAP_ASSESSMENT.md` (four memory stores), `ACCEPTANCE_E2E.md` step E4 ("the store named by lane L3").
**Evidence base:** WHOLE-SYSTEM-E2E dry run 2, `aien-sovereign-core` `docs/campaigns/whole-system-e2e/runs/RUN-1-dry-20261010T134202Z/` (receipt `chain/007-E4.json`, artifact `E4-propose.json`: `memory.state not_engaged`, `items_included 0`, after `compose remember` returned ok).

---

## Decision

1. For the first public release, the memory that step E4 of `ACCEPTANCE_E2E.md` tests is the existing **aien-allen-memory** store attached to an **engaged Aien identity**. A rename of that crate to `aien-subject-memory` is planned, not done: sovereign-core main still ships `aien-allen-memory`, `aien-allen-profile`, and `aien-allen`. The end-to-end campaign is still `docs/campaigns/allen-e2e/` (driver `scripts/allen_e2e_demo.sh`); there is no `allen-e2e` package. No new store, no new subsystem, no change to ADR 0022's statement about the Omega layer.
2. **No memory without an engaged identity.** `aien-cli compose remember` and `compose recall` refuse with the existing named refusal (NotEngaged) when Aien is not engaged. Accepting an item that can never be recalled is a silent failure and is forbidden.
3. **Every declared E2E run engages a host-built fixture Aien subject** before row E3, the way the Aien demo step S1 does (`AIEN_ALLEN_SUBJECT`, `AIEN_ALLEN_ADOPT`, log line `ALLEN: engaged`; rename of those identifiers planned), and records the identity fingerprint in its receipts. Real subjects come only from AIENOS provisioning and stay NOT_RUN in v1, as the demo already states.
4. The other three stores named in the gap assessment (compose journal records, provenance receipts, Omega rx_cortex) are not "memory" in the sense of E4; they remain what they are (durable execution state, evidence, and the Omega-layer owner respectively). CTRL-E4 (store removed) therefore tests loss of the Aien memory store, not loss of the compose journal; the dry run 2 control, which removed the whole compose home, is recorded as store-loss detection only.

## Why

The dry run showed the mechanism already exists and works when engaged; what failed was the configuration and the silent acceptance. Adding a second memory path for a daemon without identity would widen the architecture during release qualification, which Drake's directive forbids, and would contradict ADR 0035, which makes Aien the carrier of continuity.

## Consequences

- aien-sovereign-core#386 repair: remember and recall refusals when not engaged; harness engagement; the append budget fix.
- `ACCEPTANCE_E2E.md` is frozen and names "the store named by lane L3"; this ADR is that name. The E4 receipt field `memory_store` names `aien-allen-memory` (rename of that value to `aien-subject-memory` planned).
- A future ADR may add memory for an un-engaged installation; it is not on the v1 critical path.

## Not decided here

Whether the Omega-layer owner (ADR 0022) and aien-allen-memory merge or stay layered; the model's use of recalled items beyond the E4 check; anything about native AIENOS provisioning of real subjects.
