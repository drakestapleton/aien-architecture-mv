## Issue-first tracking

**Tracking issue:** Refs owner/repo#NUMBER (use `Closes #NUMBER` only for final acceptance).
**Gates advanced and status:** PASS / FAIL / INCONCLUSIVE / NOT_RUN / BLOCKED
**Source, test and qualification evidence:** Link exact code/commits, commands and receipts.

- [ ] Implementation issue exists and its scope/ownership is current.
- [ ] This PR documents remaining unrun/failed gates.
- [ ] Issue ledger will be reconciled when this PR merges.

See [`docs/process/ISSUE_FIRST_DELIVERY.md`](https://github.com/aien-dev/aien-architecture-mv/blob/main/docs/process/ISSUE_FIRST_DELIVERY.md).

## Architecture change

### Responsibility changed

What subsystem responsibility changed?

### ADR

Link existing ADR or include a new one.

### Implementation evidence

If this PR updates implementation-status claims, link the exact code/PR/commit/tests.

### Security boundary

Does this alter policy, secrets, effects, identity, provenance, or speculative execution?

### Failure behavior

What happens on Machine/provider/network/process failure?

### Diagrams

Update affected Mermaid flows.

### Checklist

- [ ] Planned work is not described as implemented.
- [ ] Machine naming remains hardware-neutral.
- [ ] Tool/Skill/World/Cortex/J-Space responsibilities remain distinct.
- [ ] External irreversible effects still require AEGIS + Effect Broker.
- [ ] Secrets do not enter model-visible or provenance state.
