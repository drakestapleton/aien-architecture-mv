> **SUPERSEDED / HISTORICAL — DO NOT USE AS AN ACTIVE IMPLEMENTATION PLAN**
>
> Original path: `docs/12-roadmap.md`
>
> Archived on 2026-09-27 during plan consolidation. The active cross-project execution plan is [CURRENT_EXECUTION_PLAN.md](../../../../CURRENT_EXECUTION_PLAN.md), governed by [PLAN_AUTHORITY.md](../../../../PLAN_AUTHORITY.md).
>
> Retained for provenance only.

---

# Roadmap

## Phase 0 — invariants

- Tool vs Skill semantics
- World vs Cortex vs J-Space separation
- no vendor-specific scheduler API
- no model-owned secret
- no irreversible speculative effect

## Phase 1 — capability plane

Build:

```text
aien-capability
aien-skill-router
```

## Phase 2 — canonical MCP

Build:

```text
aien-sovereign-core/crates/aien-mcp
```

Sequence:

1. `McpWire` seam
2. in-memory provider
3. `rmcp`
4. session manager
5. discovery snapshots
6. provider migration

## Phase 3 — credentials and effects

- `VaultOnly`
- `CredentialRef`
- Machine-aware resolvability
- Effect Broker
- mail as first migrated effect
- Git publish next

## Phase 4 — signed World commit

Bind effects, policy, runtime/model identity, and evidence.

## Phase 5 — Model Capsule and typed weight ABI

No production FP32 expansion of large BF16/quantized weights.

## Phase 6 — portable accelerator

- CPU
- Mojo
- parity/performance suite
- no mandatory CUDA build dependency

## Phase 7 — Fabric

- `aien-node`
- Machine IDs
- discovery
- QUIC
- capability advertisement
- topology metrics
- leases/failover

## Phase 8 — J-Space

Start with meaningful decision boundaries and distributed whole-branch execution.

## Phase 9 — model distribution

Content-addressed chunks.

## Phase 10 — Relational Path Engine

Use it for Cortex, capability routing, and J-Space only after A/B benchmarks.

## Phase 11 — fine-grained distributed inference

Only where measured topology shows value.

## Phase 12 — RSI optimization

Let RSI tune routing, placement, path width, kernel plans, and caches under existing safety gates.
