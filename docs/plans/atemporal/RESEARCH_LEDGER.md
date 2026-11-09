# Atemporal research ledger: what is established, what was demonstrated, what was measured, what is only a hypothesis

Status: RECORD (not a plan, not a charter). Written 2026-10-10 after Drake closed AT-1 administratively (omega#371). It sorts every claim of the AT-0 and AT-1 programs into four classes so that nobody reading the program later mistakes one class for another. It adds no new result. It is amended only by appending dated entries; the AT-0 and AT-1 results files (`AT0_RESULTS.md`, `AT1_RESULTS.md`) stay the graded record.

The four classes follow the research goal's own wording:

- **Established mathematics**: theorems and constructions in the literature or provable by hand; true independently of my software.
- **Computational demonstrations**: things my code did, graded by my evaluator and reviewer, on named machines and commits. These are statements about software conformance to a specification.
- **Experimental physics**: measurements of nature. This program has none.
- **Unverified hypotheses**: statements the program was motivated by or points toward, with no evidence either way from this work.

## 1. Established mathematics (true regardless of my code)

| item | statement | source |
|---|---|---|
| M1 | Page-Wootters construction: for a finite clock with Hamiltonian `H_C` and a system `H_S`, a joint state `Psi` in the kernel of `H_C (x) I + I (x) H_S` yields conditional system states `phi_k = (<t_k| (x) I) Psi` indexed by clock readings; for an ideal (non-degenerate, covariant) clock these obey the Schrodinger equation in the reading `k`. | Page and Wootters, Phys. Rev. D 27, 2885 (1983); Giovannetti, Lloyd, Maccone, Phys. Rev. D 92, 045033 (2015). Reproduced in `AT0_SPEC.md` section 13 hand tables (reviewer re-derived P1 and P2 values by hand, `AT0_RESULTS.md` C4, `AT1_RESULTS.md` C4). |
| M2 | With a clock-system interaction `V` that is not clock-diagonal, the conditional state obeys a modified (time-nonlocal) equation; the ideal Schrodinger prediction fails in a computable way. | Smith and Ahmadi, Quantum 3, 160 (2019). The AT-1 N1 family encodes a specific instance where the ideal prediction fails and the interacting prediction holds (`AT1_SPEC.md` section 13, `AT1_RESULTS.md` C6). |
| M3 | For a two-level clock with energies `E = (-3, 3)`, `H_S = 5 Z`, clock-pair hopping `V = g(|E0><E1| + h.c.) (x) Z` with `g = 4`, and `psi_0 = (1, 1)`: the kernel projection gives reading probabilities `p(t0) = 1/10`, `p(t1) = 9/10`; `P(Z+ | t) = 1/2` at both readings (equal to the ideal value, because `Z` commutes with `H`); `P(X+ | t1) = 0` against the ideal `3/4`. Exact rationals, machine-checked. | omega#371 correction comment 6097916958 (std-only Rust, i128 rationals, program inline). This replaces the hand-derived numbers in the AT-2 candidate note (41/50, 9/50, 1/82), which were wrong. |
| M4 | Semantic identity by hashing exact rational text, with computed binary64 values carried as evidence and never as identity, makes the identifier independent of platform rounding by construction. | `AT0_RESULT_V2.md`, `AT1_RESULT_V1.md` section 6; a definitional property of the contract, not an empirical finding. |

## 2. Computational demonstrations (what my software did, on named commits and machines)

All entries are software conformance to `AT0_SPEC.md` or `AT1_SPEC.md`. None is a statement about nature. Grades are Agent 6's (`AT0_RESULTS.md`, `AT1_RESULTS.md`).

| item | demonstrated | grade and record |
|---|---|---|
| D1 | A finite clock-diagonal Page-Wootters model (AT-0) in C11, an independent closed-form oracle in Rust, and an evaluator in Rust agree on 12 positive and 8 negative public classes plus 6 hidden cases, with exact refusal codes. | AT-0 C2, C4, C5, C6, C7 PASS; omega run 3 `712469d` (`evidence/AT0/20261010T005447Z-712469d/`), hidden run `bff4a42`. |
| D2 | The interacting regime (AT-1): the engine reproduces the specified interacting prediction and the ideal prediction fails exactly where the spec says (N1 family, `SCHRODINGER_DEVIATION_EXCEEDED`). | AT-1 C5, C6 PASS; omega `ff81466`, `evidence/AT1/20261010T044344Z-18e1786/`. Power limit: only two mutants were compiled from the real engine source at review time; follow-up omega#385 added real-engine mutants M2, M4, M5, M6, M8 matching the evaluator's receipt cells. |
| D3 | Independent execution on a second machine (macOS arm64, Apple clang 17, rustc 1.97.1) from a single-commit clone, with 21 withheld cases committed by digest before the freeze: every public `verdict_id` byte-identical to the Spark run, withheld 21/21 match. | AT-1 C8 PASS (as independent execution, not independent evaluator); omega `a392c39`, `evidence/AT1/replication-macbook/`. |
| D4 | No clock, counter, raw system call, random source or network reaches the compute objects; planted time-reading mutants are caught by symbol and instruction scans on both machines. | AT-0 C3, AT-1 C3 PASS, limited (scans see named symbols and scanned instructions only). |
| D5 | Discrete verdicts are unchanged under wall-clock variation on the tested conditions: time zone change, two passes 2 s apart, cross-machine runs 35 minutes apart, and the system clock set to 2028 and to 2023 (27/27 hidden and 24/24 public `verdict_id` and values identical). | AT-1 C9 PASS, limited; clock-shift control omega#396 `16e729b6`. Binary64 values moved by one or two ulp on 2 of 24 files across platforms, inside their written bounds. |
| D6 | Error bounds are declared `ESTIMATED` everywhere; a demand for `RIGOROUS` bounds is refused (`BOUND_KIND_INSUFFICIENT`) rather than faked. | AT-0 C10, AT-1 C11 INCONCLUSIVE (not claimed). No rigorous bound exists in the program. |
| D7 | Blinded qualification by a party that could not have influenced the candidate. | AT-0 C9, AT-1 C10 INCONCLUSIVE: every agent, the replicating operator included, is a session of one human operator's orchestrator under one GitHub account. Commitment digests prove the withheld files were fixed before the freeze; they do not prove non-access. Only a human-separated operator can move this (AT-1 review section 5 item 5; Drake's call, deferred 2026-10-10). |

## 3. Experimental physics (measurements of nature)

None. The program made no measurement of any physical system. Nothing in AT-0 or AT-1 is evidence about whether time, space, gravity or dynamics emerge from anything. This line is kept deliberately so the absence is on record.

## 4. Unverified hypotheses (the motivation; no evidence from this work either way)

| item | hypothesis | what would count as evidence, and what this program did not do |
|---|---|---|
| H1 | Time is emergent: physical dynamics can be recovered from correlations between a clock subsystem and the rest, with no fundamental time parameter. | A distinguishing prediction of a relational model, tested against a measurement that a fundamental-time model predicts differently. AT-0 and AT-1 reproduced the known construction in software (C11 and C12 NOT TESTED by charter and by Drake's decision). |
| H2 | Space, gravity and dynamics emerge from deeper computational or relational principles. | Not addressed by any contract, spec, case or run of AT-0 or AT-1. No model of space or gravity exists in the program. |
| H3 | The Atemporal AIEN Postulate (aienos.com, v1.1): meaning in AIEN must carry no wall-clock dependence; semantic identities are exact. | This is a design discipline for software, verified as M4 and D5, not a hypothesis about nature. It is listed here because it motivated the program's name and must not be read as a physics claim. |
| H4 | AT-2 candidate: clock-pair hopping couplings (M3) form the smallest exactly solvable non-clock-diagonal family worth a frozen spec. | A chartered program with frozen contracts, a second operator and an independent evaluator. NOT chartered (Drake, 2026-10-10). The exact numbers are M3; nothing else about AT-2 exists. |

## 5. What a scientifically justified next experiment would need (record, not a plan)

1. For D7 to change: a human-separated operator (Drake himself, or a non-Claude agent under a second GitHub identity on the Mac) authors the withheld set and runs the replication. This is the only open AT-1 item and it is Drake's call; no agent can produce it.
2. For D6 to change: an interval-arithmetic or exact-rational reference for the engine's binary64 values. The M3 program (i128 rationals) shows the exact path is feasible for small cases.
3. For section 3 to stop being empty: a prediction that differs between a relational model and a fundamental-time model, and a measurement. Nothing in the program's scope offers one; this is honest ground for saying the program is software, not physics.
4. Resource rule in force (Drake, 2026-10-10): no main engineering capacity for physics while AIEN's first public release is being finished (aien-architecture#190). Items 1 to 3 wait.

## 6. Record

- AT-0: charter `AT0_CHARTER.md` (REVIEWED), results `AT0_RESULTS.md` arch `21119a9`, tracking omega#358.
- AT-1: charter `AT1_CHARTER.md` (REVIEWED), results `AT1_RESULTS.md` arch `e5dd3c3`, tracking omega#371, closure comment 2026-10-10, correction comment 6097916958.
- This ledger: appended, never rewritten. A new program version (AT-2 or later) adds rows with its own commit references.
