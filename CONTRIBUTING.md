# Contributing to AIEN Architecture

Architecture changes must answer four questions:

1. **Owner:** which subsystem owns the responsibility?
2. **Boundary:** what typed protocol crosses into or out of it?
3. **Failure:** what happens if the subsystem, Machine, network, provider, or model fails?
4. **Evidence:** how can the behavior be tested and proven?

## Rules

- Do not describe planned work as implemented.
- Use **Machine 1**, **Machine 2**, etc. in architecture diagrams.
- Hardware/vendor names belong only in capability examples.
- Distinguish Tool, Skill, World, Cortex, J-Space, policy, effect, and provenance.
- External irreversible effects must pass AEGIS and the Effect Broker.
- Models never own raw credentials.
- MCP is a compatibility transport under the Capability Graph, not the internal semantic model.
- New architectural decisions require an ADR.
- Changes to security boundaries require explicit negative tests.
- Claims about current code should name the repository/path or PR/commit that establishes them.

## ADR workflow

Create `docs/adr/NNNN-short-title.md` containing:

- Context
- Decision
- Alternatives considered
- Consequences
- Security implications
- Performance implications
- Migration plan
- Acceptance tests

## Architecture-gap workflow

Open an issue when:

- current code contradicts an ADR,
- two repositories claim ownership of the same canonical behavior,
- a required typed boundary does not exist,
- a bypass exists around policy/provenance,
- documentation refers to a component that no longer exists.

## Crumbs

This repo uses the Crumb Protocol (RFC-0001). Each directory carries a `.crumb` file (what the directory is for, its rules, and a backfilled history). Agents on one machine may keep local scratch state in `.crumb.local`, which is never committed; coordination between agents goes through tracked claims and draft pull requests (see Scope in `docs/CRUMB_PROTOCOL.md`).
Before editing a directory, read its `.crumb`. Rules and the `crumb` tool: https://github.com/aien-spark/aien-architecture/blob/main/docs/CRUMB_PROTOCOL.md
Backfilled history (marked as such, not live whispers) is in `docs/crumbs/BACKFILL.md`.
