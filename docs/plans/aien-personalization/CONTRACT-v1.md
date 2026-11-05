# Aien persona profile contract v1 (`aien.allen.profile/1`)

Part of the finite workstream in `README.md` (not a master plan). Issue: aien-spark/aien-architecture#159. This is a proposed contract for review. It is not an accepted ADR, freezes no native format, and the SubjectState ([aienux docs/adr/0018-allen-subject-state-object.md](https://github.com/aien-dev/aienux/blob/9e0e6179140e9571a95f19a1b707ac576e16c859/docs/adr/0018-allen-subject-state-object.md), kind 24) is not changed by it. The implementation is the **sovereign-core persona profile PR (pending)**; where this text and that code differ, the code is the evidence and the difference is a bug in one of them.

## 1. Ownership

| Concept | Owner | Stored where | Never |
|---|---|---|---|
| Identity | Aienux provisions; host `aien-allen` resolves (read only; rename to `aien-subject` planned) | SubjectState kind 24 in the Aienux Store, host pin `<home>.allen-binding` (rename to `<home>.aien-binding` planned) | Created or edited by host or frontend code. A display name is not identity. |
| Persona profile | Host crate `aien-allen-profile` (ships on sovereign-core main) is the only writer (rename to `aien-subject-profile` planned) | `<home>.allen-profile/` beside the binding file (rename to `<home>.aien-profile/` planned) | A second copy that claims to be current. Caches carry the revision and refuse identity mismatch. |
| Working preferences | Same profile record | Same store | Treated as permissions or as facts from model output. |
| Standing intent | Aienux (SubjectState) | Subject intents (v0: `GOAL_LATENCY` only) | Written by the profile. Not covered by v1 (see AUDIT-v1). |
| Memory | Cortex (ARCH-0022) | Cortex journal | Duplicated into the profile. The profile holds no memory content. |
| Permissions | Approval desk and capability authority (S4 `authorize`, Aienux) | Their own records | Granted by profile text. |
| User account/session | Not defined in v1 | n/a | Interchangeable with the logical agent id. One local operator per compose home. |

One subject per configured root. Multi-subject, multi-device sync, clone and fork are out of scope and refused, not implied.

## 2. Schema `aien.allen.profile/1`

One JSON object per revision file, at most 16 KiB, parsed with unknown fields denied.

| Field | Type and limit |
|---|---|
| `schema` | exactly `"aien.allen.profile/1"` (rename to `"aien.subject.profile/1"` planned) |
| `agent` | 64 hex chars, the resolved LogicalAgentId |
| `root` | 64 hex chars, the resolved AgentRoot |
| `revision` | integer, starts at 1, increases by exactly 1 |
| `prev_sha256` | hex sha256 of the previous revision file bytes; all zeros for revision 1 |
| `written_at` | UTC string, informational only, never used for ordering |
| `author` | `"user"`, `"reset"` or `"revert:N"` |
| `note` | at most 200 characters |
| `persona.display_name` | 1 to 64 characters after trimming, no control characters |
| `persona.tone` | `neutral`, `warm`, `direct` or `formal` |
| `persona.verbosity` | `brief`, `normal` or `detailed` |
| `persona.plain_language` | boolean |
| `working_preferences` | at most 32 entries: `key` matching `^[a-z0-9_.-]{1,48}$`, `value` at most 200 characters, `scope` one of `all`, `personal`, `work`, `project`, `provenance` exactly `"user_explicit"` |

Preference keys containing `grant`, `permission`, `approve`, `capability`, `allow` or `authori` are rejected with the reason "permissions are not profile fields; approvals go through the approval desk". No avatar, voice, memory or credential fields exist in v1. Status reports avatar and voice as unsupported. Defaults when no profile exists: display name `Aien`, tone `neutral`, verbosity `normal`, plain_language false, no preferences.

## 3. Revisions, crash safety, concurrency

1. The store is immutable revision files `r00000000000000000001.json`, `r...2.json`, and so on. Nothing is edited in place.
2. A write goes: temp file, write, fsync, hard link temp to `rN` (fails if `rN` exists, which means another writer won, reported as StaleUpdate), fsync the directory, remove the temp file. A crash leaves the old head or the new head, never a mix. Leftover temp files are ignored.
3. The head is the highest N with a valid contiguous chain 1..N, each `prev_sha256` matching the previous file's bytes.
4. Every change names the revision it expects (`--expect R`, compare-and-swap). A mismatch is StaleUpdate and changes nothing. With concurrent writers exactly one wins.
5. Undo is revert: a new revision that copies an earlier one (`author: "revert:N"`). Reset is a new revision with defaults (`author: "reset"`). Neither touches identity or deletes history.
6. A damaged, foreign, or unknown-schema file is a clear refusal. It is never silently replaced and never causes a new subject to be created.

## 4. Refusal list

The writer refuses: profile with no engaged identity; `agent` or `root` different from the resolved identity (ForeignProfile); stale `--expect`; malformed JSON; unknown schema; unknown field; file over 16 KiB; any field over its limit; a permission-looking preference key; a broken or gapped revision chain. Model output has no code path to the writer.

## 5. Precedence

1. The current instruction (goal text of the request) wins over any saved preference.
2. Saved preferences are style choices only. They rank below project constraints and below authoritative permissions.
3. Permissions never come from the profile. A write still needs S4 `authorize` and S5 `execute` whatever the profile says.
4. Retrieved or external content is untrusted and cannot change the profile.

## 6. Enforced versus advisory

| Item | Class | Mechanism |
|---|---|---|
| Identity binding of the profile (agent and root equal the resolved identity) | Enforced | Checked on every read and write. |
| Schema, limits, revision chain, compare-and-swap | Enforced | Writer code and tests. |
| No permission grant from profile | Enforced | Key rejection plus authorization unchanged at its own boundary. |
| Display name in reports | Enforced (report field) | `ComposeTaskReport` carries persona state, name and revision. |
| Tone, verbosity, preferences shaping model text | Advisory | A bounded block (at most 2048 bytes, preferences sorted by key, overflow dropped and counted) in the prompt. A model may ignore it. Real-model effect is NOT_RUN. |

## 7. Migration

A reader accepts exactly `aien.allen.profile/1`. Any other schema value is refused with a clear message. A future v2 needs an explicit migrator that reads a v1 chain and writes a new revision in the v2 form, never an in-place rewrite and never a silent upgrade on read. Sovereign-core main still ships that schema from crate `aien-allen-profile` under `<home>.allen-profile/`. A rename of the schema string to `aien.subject.profile/1` and of the store directory to `<home>.aien-profile/` is planned, not done; no daemon-start migrator ships on main.

## 8. The nine issue invariants and how v1 keeps each

1. **LogicalAgentId and AgentRoot identify Aien.** The profile stores those two values and refuses a mismatch. No `AienId`.
2. **Display name is not identity or authorization.** It is a free field in `persona`; nothing keys on it.
3. **SubjectState independent of weights, KV, machine, queues.** SubjectState is untouched; the profile is a separate host record.
4. **Aien is not a planner, UI, scheduler or loop.** The profile is passive data read when a request is built.
5. **Cortex owns memory.** The profile has no memory fields and no journal copy.
6. **Aienux is the provisioning and capability authority.** Host code only attaches to an existing subject; permissions stay with the approval desk.
7. **Missing identity is not repaired by creating another.** Not engaged means profile commands refuse; nothing is minted.
8. **v0 has one subject per root and limited intent semantics.** v1 supports one subject per root and claims no general goals or multiple subjects.
9. **INTERPLANE is interface and transport.** v1 changes no INTERPLANE wire format; any presentation extension would be a separate, explicitly versioned contract.
