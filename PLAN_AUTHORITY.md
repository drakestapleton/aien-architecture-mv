# AIEN Plan Authority

**Status:** AUTHORITATIVE  
**Effective:** 2026-09-27

AIEN has accumulated architecture reviews, roadmap snapshots, implementation plans, milestone plans, and research plans. They are useful historical records, but they are not allowed to compete as active instructions.

## The three whole-system authorities

1. **Architecture:** `doctrine/ARCHITECTURE.md`  
   Defines what the system is, subsystem ownership, permanent boundaries, and canonical terminology.

2. **Milestone registry:** `doctrine/ROADMAP.md`  
   Owns canonical milestone identifiers and milestone status. Historical milestone names remain immutable even when a subsystem is later renamed.

3. **Execution sequence:** `CURRENT_EXECUTION_PLAN.md`  
   Defines what the project should do now and in what order. This is the only active cross-project master implementation plan.

No other file may present itself as the canonical, master, final, complete, authoritative, or current whole-system plan.

## Component-local plans

Component repositories may keep local roadmaps and acceptance specifications for their own scope. They must not redefine the whole-system architecture or duplicate the cross-project execution sequence.

Examples:

- `aien-dev/aienux/ROADMAP.md` is the Aienux component roadmap.
- Omega milestone specifications define acceptance contracts for individual Omega milestones.
- Historical Physics/Forge milestone specifications and receipts remain evidence records.
- A finite workstream plan under `docs/plans/` is allowed only when its scope is explicit and it is marked **NOT A MASTER PLAN**.

When a component plan conflicts with these authorities, this repository wins for architecture and cross-project sequencing. Current implementation code and evidence still win for claims about what is actually implemented.

## Historical plan archive

Superseded whole-system plans live under:

`docs/archive/plans/`

Every archived file carries a **SUPERSEDED / HISTORICAL** banner. Archived files are provenance, not instructions.

Agents must not:

- derive current milestone status from archived plans;
- reopen settled architecture because an archived document used older terminology;
- treat historical PHYSICS names as a reason to undo the FORGE rename;
- infer implementation status from a plan instead of current code/evidence.

## Naming rule: PHYSICS -> FORGE

As of 2026-09-27, the current machine-realization subsystem is **FORGE**.

Historical identifiers such as `PHYSICS_BOOT`, `PHYSICS_EFFECTS`, `PHYSICS_ACCELERATOR_LINK`, old receipt fields, old artifact names, and old repository history remain unchanged. They describe what existed at the time.

Current architecture uses:

`ATLAS AWAKENS. ALLEN INTENDS. AIEN PROPOSES. OMEGA DEFINES. FORGE REALIZES. AEGIS VERIFIES. HARDWARE ACTS. EVIDENCE TEACHES.`

This sentence is responsibilities and causal dependencies, not a turn order and not the way a reaction result is accepted. FORGE is a realization and memory policy; the accept chain is World -> J-Space -> `compose.verify` -> commit -> Cortex (ADR 0016 Amendment 1, 2026-10-02).

The repository `aien-spark/physics` remains a historical/current implementation location until its GitHub repository rename is performed. A repository-name transition does not rewrite old evidence.

## Change discipline

A proposed change to whole-system sequencing must update `CURRENT_EXECUTION_PLAN.md`.

A proposed change to subsystem responsibility must be recorded as an ADR and reflected in `doctrine/ARCHITECTURE.md`.

A milestone status change must update `doctrine/ROADMAP.md` and cite evidence or an explicit corrective-reopen decision.

If a new document appears to be another master plan, stop and fold the useful material into the existing authority instead.
