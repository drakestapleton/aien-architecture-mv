# Sealing Procedure for Discovery Exam Holdouts

**Status:** PROPOSED, 2026-10-01. Draft procedure only. Nothing in this document is implemented, run or sealed. No real held-out data, salt, key or signature exists for any exam.
**Serves:** ARCH-0026 (`docs/adr/0026-sealed-discovery-examinations.md`, merged `5910dff`), section 2 items 2 and 4, section 5 row "G3 sealed evaluation", section 7 item 1.
**Reuses, unchanged:** the G3 commitment, signature and reveal formats in omega `spec/searchtrace/G3_SEALED_HOLDOUT_COMMITMENT_V1.md` (code `src/searchtrace/st_holdout.{h,c}`); the owner key chain made by the TRUST-1 offline key ceremony (aienos `docs/TRUST-1-OPERATOR-STEPS.md` Step 8, `scripts/trust1_key_ceremony.sh`); the receipt rule of ARCH-0021 decision 3; the held-out and leakage policy of `docs/plans/dirac/DIRAC-0-SPEC.md` sections 7.1 to 7.4.
**Companion:** exam data layout V0 (draft, EXAMS-DATA, aien-architecture PR #99, `docs/plans/physics-zero/SEALED_EXAM_DATA_LAYOUT_V0.md`, called "layout draft" below). The layout draft owns the manifest fields, file names and examinee view. This document owns the sealing items the layout draft hands over (section 3a) and defines no manifest field.
**Not a master plan.** `CURRENT_EXECUTION_PLAN.md` owns sequencing and `doctrine/ROADMAP.md` owns milestone status. Code beats plans. Nothing here raises any status.

**Terminal state of this procedure today: AWAITING OWNER SIGNATURE.** The procedure stops at the owner's signature (section 4, step S8). No agent signs, uses a TEST key in place of the owner key, or treats this draft as the owner's decision.

---

## In plain words (read this first)

An exam is only fair if the answers are locked away before AIEN starts. Sealing works like a sealed envelope with a fingerprint printed on the outside:

1. The evaluator side prepares the exam's hidden test data and mixes in a long secret random number (the "salt").
2. A program computes a fingerprint (a hash, a short code that changes completely if even one byte of the data changes). The fingerprint is written into a small public record. Because of the salt, nobody can guess the data from the fingerprint.
3. Drake signs that small record with his owner key. His signature says "this is the envelope I approved, on this date, before any exam run".
4. Only then may AIEN take the exam. AIEN never sees the hidden data.
5. After AIEN's answers are frozen, the envelope is opened once. A program checks that the opened data matches the fingerprint exactly, and writes a receipt.

If anything leaks before the opening, or the order is broken, the seal is void and that exam attempt does not count.

## 1. Sources and what each one fixes

| Item | Fixed by | Pointer |
|---|---|---|
| Commitment hash, salt digest, record text, file name | G3 format V1 | omega `spec/searchtrace/G3_SEALED_HOLDOUT_COMMITMENT_V1.md` lines 22 to 52 |
| Owner signature (Ed25519, detached file) | G3 format V1, "Owner signature" | same spec, lines 112 to 162 |
| Reveal check and reveal receipt | G3 format V1 | same spec, lines 63 to 85 |
| The real signature is made only in the offline owner key ceremony | G3 format V1 | same spec, lines 159 to 162 |
| Salt generation, sealed storage, real owner signing, publication to a timestamped place | Out of scope of G3 V1 | same spec, lines 164 to 168 |
| Owner keys (four roles, encrypted from creation, offline machine) | TRUST-1 Step 8 | aienos `docs/TRUST-1-OPERATOR-STEPS.md` Step 8; `scripts/trust1_key_ceremony.sh` |
| G3 order: commit, train, freeze, reveal, evaluate once, receipt | Plan G3 | `CURRENT_EXECUTION_PLAN.md` section G3 (lines 491 to 506) |
| Sealing BLOCKED_OPERATOR (salt, storage, owner signature) | Plan status | `CURRENT_EXECUTION_PLAN.md` lines 93 and 506 |
| Leakage checklist, no self-control, held-out policy | DIRAC-0 spec | `docs/plans/dirac/DIRAC-0-SPEC.md` sections 7.1 to 7.4 |
| Hidden-oracle isolation | Law Atlas V1 draft | `docs/plans/physics-zero/PHYSICS_ZERO_LAW_ATLAS_V1.md` section 4 |
| Leakage canary and hostile controls | ARCH-0026 | section 3 |
| Receipts append-only, bound to a clean commit | ARCH-0021 | decision 3 |

## 2. Roles

| Role | Who | May do | May never do |
|---|---|---|---|
| Owner | Drake | Generate or approve the salt source (OPEN: owner decision, section 10 item 5); sign the commitment record; authorize an unseal; declare a seal void | Be asked to sign a record he has not been shown in plain words (section 4, step S8) |
| Evaluator preparer | An evaluator-side agent lane named per exam in the exam's preregistration. OPEN: owner decision whether one standing lane or one lane per exam | Run the hidden generator, assemble the sealed set per the layout draft and section 3a, plant canaries, produce the unsigned commitment record | Build, run, tune or brief the examinee; hold the owner key; sign |
| Custodian | OPEN: owner decision (section 10 item 5). Candidate places already named in specs: a private repository or an offline store on the evaluator side (DIRAC-0-SPEC 7.1 "Repository" row); `aien-dev/aien-sealed` is a private repository described as holding answer keys and evaluator-only specs (UNVERIFIED as the chosen store for exam holdouts) | Hold the sealed set and the salt; release them only at the unseal step | Copy them into any place AIEN can read |
| Examinee | AIEN (the candidate under test) | Read only the training observations and generic tools ARCH-0026 section 1 allows | Read, choose or score its own holdout, baseline or scoring (DIRAC-0-SPEC 7.3) |
| Leakage reviewer | Independent of the preparer and of the examinee lane (DIRAC-0-SPEC section 7.1 last line). OPEN: owner decision who | Scan AIEN-readable material for canaries; sign off the leakage review referenced by the receipt | Edit the sealed set |

The preparer and the examinee lane must be different agents with no shared working tree. A lane that has seen the sealed set may not later build or brief the examinee for the same exam.

## 3. What gets sealed, per exam attempt

One G3 commitment covers one opaque byte file (the G3 "taskset") under one `holdout_id` (G3 spec lines 13 to 20). For an exam attempt the sealed material is:

- the held-out observations for that attempt (ARCH-0026 section 4, "Sealed held-out observations" of each exam);
- each hostile control set and decoy world that needs its own data (ARCH-0026 section 3; layout draft section 4 table);
- the answer key and generator identity, if the exam's preregistration seals them in the same set.

The leakage canary is not part of any G3 taskset. Only its digest is recorded (layout draft section 4, "Leakage canary: no data set"; section 3a item 5 below).

Separately from the sealed set, the following are frozen and committed by digest before any examinee run (ARCH-0026 section 2 item 2; plan G3 list; DIRAC-0-SPEC D2.0 and 7.4): the TURING profile, metrics, thresholds, allowed data and operations, baselines, hostile-control list, budgets, seeds and splits. Where that digest is recorded: section 3a item 4. The pass bar stays incomplete until the TURING owner accepts or rejects "net Turing gain" (ARCH-0026 section 2).

## 3a. Items this procedure owns from the exam data layout

The exam data layout draft (aien-architecture PR #99, `docs/plans/physics-zero/SEALED_EXAM_DATA_LAYOUT_V0.md`) hands the items below to this sealing procedure. This procedure owns each of them. Where no existing spec fixes the content, the item says OPEN or TO BE FIXED BY a named spec. This draft invents no format.

1. **How exam data becomes G3 task lines (packing).** Fixed today: the G3 taskset is opaque bytes; `task_count` counts lines whose first five bytes are `task `, and a file with zero such lines is refused (G3 spec lines 13 to 18). Observation records are OMG0 canonical encoding (layout draft section 2.2, citing DIRAC-0-SPEC section 8). Not fixed: how one observation record, or a group of them, is written as one `task ` line, and how binary OMG0 bytes are carried in a line-based file. TO BE FIXED BY M27 PHYSICS_ZERO_PROTOCOL (`doctrine/ROADMAP.md` line 66, "sealed evaluation benchmark contracts"), together with the observation record encoding that the layout draft already sends there. If no line form fits, G3 needs a new version; this document does not change G3.
2. **How many `holdout_id` values per attempt.** Adopted from the layout draft section 2.1 (`holdout_id`, `control_sets`) and section 4: the real held-out set has its own `holdout_id` and G3 commitment, and each control or decoy set that needs data has its own `holdout_id` and G3 commitment. Each commitment record is a separate file, so each needs its own owner signature file `g3-sig-<record_digest>.txt` (G3 spec lines 129 to 135). The S7 summary lists every record of the attempt, and step S8 covers each one.
3. **`generator_ref` preimage.** Content fixed by Law Atlas V1 section 4 item 2: a hash over the generator build, the world list and the scoring code. For Exam A the generator is D-11 (DIRAC-0-SPEC section 14), not built. The exact byte preimage and its digest domain string: TO BE FIXED BY M27 PHYSICS_ZERO_PROTOCOL. It is recorded at S2, before S5.
4. **Preregistration digest location.** The frozen exam Turing profile digest goes in the layout draft's `turing_profile_ref` (layout draft section 2.3, following omega `docs/turing/TURING_YIELD_PROFILE_V0.md`, profile digest `turing.yprofile.v0` and split digest `turing.ysplit.v0` pattern). The rest of the preregistration (metrics, thresholds, allowed data and operations, baselines, hostile-control list, budgets, seeds, splits) has no field in the layout draft. Where its digest is stored and its byte form: TO BE FIXED BY M27 PHYSICS_ZERO_PROTOCOL. Until then S1 records it in the S7 summary only, which does not count as a frozen preregistration.
5. **Leakage canary: generation, storage, digest domain, scan procedure.** Generation: fresh per attempt (DIRAC-0-SPEC 7.4 fresh-attempt rule); how the marker string and decoy equation text are generated: OPEN: owner decision. Storage: held by the custodian like the sealed set (section 7); never in any AIEN-readable place. Digest: recorded as the layout draft's `canary_digest`; its domain string: TO BE FIXED BY M27 PHYSICS_ZERO_PROTOCOL. Scan tool and scope list: TO BE FIXED BY M27 PHYSICS_ZERO_PROTOCOL (`doctrine/ROADMAP.md` line 66, "contamination firewall specification"). Section 6 gives the handling rules.
6. **`sealing_ref` storage reference.** Its contents: the commitment record name `g3-commit-<record_digest>.txt` and signature name `g3-sig-<record_digest>.txt` (G3 spec lines 22 to 52 and 135), the publication place of S10 (OPEN: owner decision), and the location of the sealed set and salt with the custodian (OPEN: owner decision; storage choice is BLOCKED_OPERATOR, `CURRENT_EXECUTION_PLAN.md` line 506). The written form of the reference depends on that storage choice and stays OPEN: owner decision.

Note on folders: the layout draft sits in `docs/plans/physics-zero/` and this draft in `docs/plans/discovery-exams/`. Neither is moved in this round. Placing both in one folder is OPEN: owner decision at merge time.

## 4. Order of steps (commit, then sign, then run, then reveal)

Every step names who does it. A step may start only after the step before it is recorded. Any break in this order voids the seal (section 9).

| Step | Who | What | Record left behind |
|---|---|---|---|
| S1 | Evaluator preparer | Freeze the preregistration (section 3, last paragraph) and record its digest (section 3a item 4) | Preregistration digest; storage and byte form TO BE FIXED BY M27 PHYSICS_ZERO_PROTOCOL |
| S2 | Evaluator preparer | Generate the held-out observations evaluator-side, from the hidden generator, outside every place AIEN can read (Law Atlas V1 section 4 item 1; DIRAC-0-SPEC 7.1) | Sealed set, held by the custodian |
| S3 | Owner, or a source the owner approves | Make the 32-byte salt from a CSPRNG (G3 spec line 19). How and on which machine: OPEN: owner decision (plan line 506 lists "secret salt generation" as BLOCKED_OPERATOR) | Salt, held by the custodian; never in any repository AIEN can read |
| S4 | Evaluator preparer | Plant the leakage canary (section 6) in evaluator-only material, and record the canary digest evaluator-side | Canary record, evaluator-side only |
| S5 | Evaluator preparer | Produce the G3 commitment record with the existing tool's `commit` subcommand (G3 spec line 89). Output file `g3-commit-<record digest>.txt`. NOT_RUN | Unsigned commitment record |
| S6 | Evaluator preparer | Check the record parses with `verify` (parse only, G3 spec line 95). NOT_RUN | Same record, unchanged |
| S7 | Evaluator preparer | Hand the owner a one-page plain summary: exam name, attempt number, and for every commitment record of the attempt (section 3a item 2) its `holdout_id`, task count and record digest; also the date, and a statement that no examinee run for this attempt has started | Summary in the orchestrator handoff |
| S8 | **Owner (Drake)** | **Sign each commitment record of the attempt (section 5). This draft stops here: AWAITING OWNER SIGNATURE.** | `g3-sig-<record digest>.txt` next to the record (G3 spec line 135) |
| S9 | Evaluator preparer | Check the signature with `verify --strict` against the owner public key from the ceremony's public folder (G3 spec lines 137 to 157). Seal state becomes SEALED only on a strict pass | Strict-verify output kept with the record |
| S10 | Evaluator preparer | Publish the commitment record and signature where the date can be proven later. Place and timestamp method: OPEN: owner decision (G3 spec line 167 leaves this out of scope) | Public copy of record and signature |
| S11 | Examinee lane | Run the exam on training observations only. No run of this attempt may start before S9 passes and S10 is recorded | Run receipts (ARCH-0021 decision 3) |
| S12 | Examinee lane, checked by evaluator | Freeze the examinee's predictions and model digest before reveal (plan G3; Law Atlas V1 section 4 item 6) | Prediction-freeze digest |
| S13 | Leakage reviewer | Canary scan and leakage review over every AIEN-readable input, corpus and output (section 6). Any hit stops here and voids the seal | Leakage review reference (DIRAC-0-SPEC section 13 `leakage_review_ref`) |
| S14 | Custodian, on owner authorization (section 8) | Release the sealed set and salt to the scorer only | Release note |
| S15 | Evaluator scorer | Run `reveal` with `OMEGA_REPO_COMMIT` set (G3 spec lines 92 to 94). A refusal writes no receipt and voids the attempt | `g3-reveal-<digest>.txt` (verdict PASS only) |
| S16 | Evaluator scorer | Score once under the frozen profile; write the exam receipt, append-only, bound to a clean commit, carrying the G3 commitment digest (DIRAC-0-SPEC section 13 `dataset_commitment_digest`) | Exam receipt, kept whether PASS or FAIL |

## 5. The owner signing step (S8), written for Drake

**Where things stand when this step comes up.** The exam's hidden test data is prepared and locked away. A small text file (the commitment record, about eight lines) holds its fingerprint. Nothing about AIEN's exam run has started. The orchestrator shows you the one-page summary from step S7.

**What you are deciding.** Whether to put your owner signature on that record. Signing says: "I approve this sealed envelope, and it existed before any exam run."

**What changes when you sign.** One new small file appears next to the record: the signature file. Nothing else changes. The hidden data is not opened, moved or copied. Your private key stays on the offline machine. Only the signature file goes back to the Spark.

**What does not change.** The exam does not start by itself. Agents first check your signature (step S9).

**What you would do (draft; several points are still OPEN, see the list after the steps):**

1. Use the offline ceremony machine from TRUST-1 Step 8, with Wi-Fi off and network cables unplugged. OPEN: owner decision which machine (TRUST-1 Step 8 decision; see section 10 item 1).
2. Copy the commitment record file onto that machine. The orchestrator will tell you its exact name. It starts with `g3-commit-` and ends with `.txt`.
3. Compare the record digest on screen with the one in the S7 summary, character by character in groups of eight. If any group differs, stop and tell the orchestrator. Do not sign.
4. Unlock your signing key with your ceremony passphrase. The exact way to unlock it for this tool is TO BE FIXED BY a signing step spec (section 10 item 3). The tool needs the key in a form the ceremony does not write directly.
5. Run the G3 tool's `sign` command on each record of the attempt, one at a time (G3 spec line 148: `sign <record_file> <secret_key_file> <out_dir>`). The exact program path on the ceremony machine is UNVERIFIED and will be given to you as one line to copy.
   - *Changes:* writes one file named `g3-sig-<record digest>.txt`. If that file already exists with the same content, it says OK. If it exists with different content, it refuses.
   - *You should see:* the path of the new signature file, and no error.
6. Remove any unlocked copy of the key that step 4 made, the way that signing step spec will say.
7. Copy only the `g3-sig-...txt` file back to the Spark (the same way the ceremony's `public` folder goes back in TRUST-1 Step 8).

**What success looks like.** An agent runs the strict check (step S9) with your public key and reports "signature verified" in plain words. Until that report, the seal does not count.

**If something looks wrong.** Stop and tell the orchestrator. Nothing is lost by not signing. A new record can be prepared.

## 6. Leakage canary handling

Source: ARCH-0026 section 3, row "Named-answer leakage canary"; DIRAC-0-SPEC section 7.1.

- The canary is a unique marker string and a decoy equation, planted only in evaluator-only material for this attempt (S4). It is never placed in the sealed set's AIEN-facing parts, prompts, Skills, Cortex, the Capability Graph, J-Space, logs or receipts AIEN can read.
- The canary text is created fresh per attempt, held by the custodian, and recorded only by its digest (`canary_digest`). Generation method, digest domain and storage: section 3a item 5.
- Scans: every AIEN-readable input, corpus and output is scanned for the marker and the decoy equation before reveal (S13), and the examinee's frozen outputs are scanned again before scoring (S16). Scan tool and scope list: TO BE FIXED BY M27 PHYSICS_ZERO_PROTOCOL (section 3a item 5).
- Expected result: zero hits. **Any hit voids the run and the seal** (ARCH-0026 section 3). The voided attempt is kept as a receipt and is never rescored. A new attempt needs fresh held-out data, a fresh salt, a fresh canary and a new commitment (DIRAC-0-SPEC 7.4).
- The canary scanner must not itself place the canary text where AIEN can read it (for example in a scan log on AIEN's path).

## 7. Custody: who can read sealed data, and when

| Material | Before S8 (signature) | S8 to S14 (sealed) | After S14 (released) |
|---|---|---|---|
| Sealed observations | Evaluator preparer, custodian | Custodian only | Custodian, scorer; then published only if the exam's preregistration says so (OPEN: owner decision) |
| Salt | Owner or approved source, custodian | Custodian only | Scorer for the reveal check |
| Canary text | Evaluator preparer, custodian | Custodian, leakage reviewer (for scanning only) | Same; never AIEN |
| Answer key, generator, decoy generator | Evaluator side only | Evaluator side only | Evaluator side only, unless the owner decides otherwise |
| Commitment record and signature | Preparer, owner | Public (they leak nothing useful; G3 spec line 36) | Public |
| Owner private key | Ceremony machine and the two backups only (TRUST-1 Step 8) | Same | Same |

The examinee (AIEN) never reads the sealed observations, salt, canary, answer key or generator at any time during the attempt. The evaluator preparer loses read access at S8 if the custodian is a separate holder (OPEN: owner decision whether access control is enforced or by rule only).

## 8. Unseal conditions

The sealed set and salt are released (S14) only when all of these hold:

1. The owner signature passed `verify --strict` (S9) against the owner public key.
2. The publication record (S10) predates the first examinee run of this attempt.
3. The examinee's predictions and model digest are frozen and recorded (S12).
4. The leakage review (S13) reports zero canary hits.
5. The owner authorizes the release. Whether this needs a second owner signature, and with which key: OPEN: owner decision.
6. The attempt has not been revealed before. A sealed set is revealed and scored once per preregistered claim (ARCH-0026 section 2 item 2; DIRAC-0-SPEC 7.4).

## 9. What voids a seal

Any one of these voids the seal for that attempt. A voided attempt keeps its receipts, is never rescored, and needs fresh data, salt, canary and commitment to retry.

1. Any examinee run of the attempt started before S9 passed and S10 was recorded.
2. Any canary hit in AIEN-readable material (section 6).
3. Sealed observations, salt or answer key found anywhere AIEN can read, at any time before scoring.
4. `verify --strict` fails, or the signature was made with any key other than the owner key named for this purpose (a TEST key never counts; plan line 93; ARCH-0026 section 7). The Spark machine-owner key (MOK, CN=AIEN Spark owner key (telemetry), enrolled 2026-09-28 for the R15 telemetry driver; omega `docs/r15-handoff.md` line 164) is never the owner key for this purpose; a record signed with it voids the seal.
5. `reveal` refuses (salt digest, length, count or commitment mismatch; G3 spec lines 63 to 66).
6. The preregistration (profile, metrics, thresholds, controls, budgets, splits) changed after S1.
7. The sealed set was revealed or scored more than once.
8. The examinee lane, or any lane that briefs it, had read access to the sealed material.
9. A hostile control did not behave as specified (ARCH-0026 section 3 says this voids the exam).

## 10. Gaps found while grounding this draft

Each item is open. None is decided here.

1. **Owner key ceremony not done; one unrelated Spark key exists.** Two facts, about two different keys. (a) The TRUST-1 offline ceremony keys (Owner Root, Boot Signer, Release Signer, Operator Approval) are not created: the real-owner rows are BLOCKED_OPERATOR, offline key ceremony (`CURRENT_EXECUTION_PLAN.md` lines 88 and 270). No owner key exists to sign exam records with until Step 8 is done. (b) A separate machine-owner key (MOK, CN=AIEN Spark owner key (telemetry)) was enrolled on the Spark on 2026-09-28 only to sign the R15 read-only telemetry driver (omega `docs/r15-handoff.md` line 164). It is not a ceremony key, it is not offline, and its private part lives on the Spark. **Rule: the Spark MOK must never sign G3 exam records** (section 9 item 4).
2. **Which key signs.** The G3 spec says "owner key". The ceremony makes four keys: Owner Root, Boot Signer, Release Signer, Operator Approval (TRUST-1 Step 8). Owner Root's stated duty is "signs authority manifests"; Operator Approval's is "approves boundary changes". Which one signs exam commitments: OPEN: owner decision. Boot Signer is RSA and cannot sign G3 records, which are Ed25519 only.
3. **Key form mismatch.** The ceremony writes private keys encrypted with a passphrase from creation (`openssl genpkey ... -aes-256-cbc`). The G3 `sign` tool accepts a 32-byte seed as raw bytes, 64 hex digits, or unencrypted PKCS#8 DER, from a file not readable by group or others, and never creates keys (G3 spec lines 148 to 151). How the owner unlocks the key for one signature without leaving it unlocked: TO BE FIXED BY a signing step spec (TRUST-1 or G3 owner).
4. **Two different key fingerprints.** G3 `key_id` is SHA-256 of the 32-byte raw public key (G3 spec line 131). The ceremony's `pub_sha256` is SHA-256 of the public key in SPKI DER form (`trust1_key_ceremony.sh`, `pub_fingerprint`). These are different numbers for the same key. Matching them needs a stated conversion step: TO BE FIXED BY a signing step spec. This draft does not define one. Tool input is not the gap: `verify --strict` already accepts the public key as Ed25519 SPKI DER (G3 spec line 155), so the ceremony public key can be used as is. Only the printed fingerprints differ.
5. **Salt generation, sealed storage, custodian, publication place.** All BLOCKED_OPERATOR or out of scope today (plan line 506; G3 spec lines 164 to 168).
6. **G3 tool on the offline machine.** The `sign` subcommand is part of omega's C tool. How it reaches the ceremony machine, and its program path there: UNVERIFIED, TO BE FIXED BY the signing step spec.
7. **Data fits G3.** Whether exam observations fit the G3 task-line rule: owned here, section 3a item 1, TO BE FIXED BY M27 PHYSICS_ZERO_PROTOCOL.
8. **Pass bar.** "Net Turing gain" is pending TURING owner review (ARCH-0026 section 2). Sealing can proceed without it, but no verdict can be PASS.

## 11. What this document does not do

- It adds no code, script, key, salt, signature, sealed data or receipt.
- It changes no G3, TRUST-1 or receipt format.
- It does not define manifest fields; the layout draft does. It owns the sealing items in section 3a and leaves their open formats to the specs named there.
- It does not sign, seal or unblock anything. G3 sealing stays BLOCKED_OPERATOR. The procedure ends at AWAITING OWNER SIGNATURE.
