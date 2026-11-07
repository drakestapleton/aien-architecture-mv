# CAND-5 gates and evidence

CAND-5 is the 2026-11-06 mains: sovereign-core `dffdbd19` (omega.lock `f9a9a40`), omega `f9a9a40` (physics.lock
`048e5f5e`, aienos.lock `b84c0a6`, argus.lock `b375dca`), with no model (engine-only, see `CAND-5.toml` `[model]`).
Cut 2026-11-07 for the first tagged Core release (Linear DRA-46, DRA-51). It supersedes CAND-4 (`CAND-4.toml` is not
edited). Evidence lives on the Spark under `~/workspace/evidence-out/CAND5-*`. Statuses as in `CAND-3.gates.md`.

## 1. Clean-worktree build (host only)

Script `cand5_build.sh` (copy in each evidence directory, sha256 `7c373da1...`), adapted from `cand4_build.sh`:
blobless GitHub clones (omega-mv, aienux, physics-mv, aien-sovereign-core-mv), detached worktrees at the CAND-5
commits, a fresh CARGO_HOME filled by `cargo fetch --locked`, every item built, hashed, deleted and built again. The
script refuses to build unless the lock chain matches the commits it was given. Differences from CAND-4: `make -j2`
under `taskset -c 8-9`; sovereign-core also builds `aien-serve-http` alone after `aien-cli` (the engine SI embeds),
so 26 digests; the release logs are searched for the GPU link mode and for "development override".

| Run | Root | Result |
|---|---|---|
| CAND5-BUILD-A | `cand5/rootA` | PASS: 26 of 26 digests identical in both builds, VERDICT PASS (summary sha256 `5c5a5696...`) |
| CAND5-BUILD-B | `cand5/rootB` (other path; CARGO_HOME a hard-linked copy at another path) | PASS: 26 of 26, VERDICT PASS (summary sha256 `569deb9c...`) |

`digests.txt` of A and B are byte-identical (sha256 `1b5435e9b23c03945c2e9d084ac0918440869bb0ac22cdeec5679f43e4632ae3`),
so the digests also agree across two roots. Checks in both roots: physics boot bins equal the committed files;
`libomega_gpu.a` carries no gate objects (G6); native engine linked (`has_omega_gpu`); composition library linked
(`has_omega_compose`); aien-cli carries the native backend string; no cargo registry path in aien-cli (G13); zero-CUDA
gate PASS; no TEST strings in the aienos production images; every worktree clean after the build. The aien-cli and
aien-serve-http release logs each show `AIEN_OMEGA_GPU_LINK=pinned-source` and `AIEN_OMEGA_GPU_DIGEST=locked`, and
0 "development override" lines. `omega-gpu-engine-lib` `2ea0d7f0...` and `omega-librx-compose` `28896316...` equal
the f9a9a40 lines of sovereign-core `native-artifacts.lock` (sovereign-core #921), an independent reproduction.

Unchanged from CAND-4 (same digest): physics-boot-bin, atlas-m2-boot-bin, aienos-boot-image, aienos-ck-core-image,
omega-rx-operator. Every other entry changed.

Release tree gate: sovereign-core branch `hive/dra-46-release-gate` pins CAND-5 in `release/candidate.toml`;
`scripts/check-release-candidate.sh` prints `candidate=CAND-5`, rc 0. A package built from root A's binaries by
`scripts/package-release.sh` passes `check-release-candidate.sh --package ... --native` (sha256 `a8ffd568...`,
byte-reproducible; `~/workspace/evidence-out/CAND5-RELEASE-PREP/`).

## 2. What CAND-5 does not prove yet

- No model is qualified: `[model]` is `none`. No real-model gate ran. The own Omega LLM is served by aien-train's
  `ollm`, not by this engine (DRA-124 selects the checkpoint).
- Qualification campaigns (useful workflow Q1, recovery Q2): NOT_RUN.
- Chip results: none; the build is host only. No GPU window was used.
- Release demo with a public key (sign, verify as `release`, install, upgrade, rollback): NOT_RUN. No public-release
  key exists until the key ceremony (Linear DRA-42, in person); the publish gate refuses the placeholder key.
- The hosted `release.yml` build on `ubuntu-24.04-arm` was not run, so whether the hosted toolchain reproduces these
  digests is NOT_RUN.
- `aien-serve-http-native-release` is the host recipe, not the DRA-43 container build that SI ships.

## 3. GPU library provenance (DRA-41)

`libomega_gpu.a` is built from omega-mv `f9a9a40` (pinned source, digest locked in `native-artifacts.lock`). That
is not a tagged commit, and omega-mv is not the canonical GPU repository: ADR 0042 and the queen decision of
2026-11-06 (si034) name aien-dev/CUDApp. Building the engine's GPU library from a tagged CUDApp commit depends on
CUDApp #280 (integration branch `integ/omega-cuda-stack`) merging, a CUDApp tag, and sovereign-core #784 (build from
`cudapp.lock`, draft). A candidate after that lands (CAND-6) replaces `omega-gpu-engine-lib`.

## 4. Checker results and gaps

- `tools/candidate/check_candidate.om` (omc `734f0a39...`): `OK: qualification/candidates/CAND-5.toml (amendments: 0)`.
- `tools/candidate/check_pins.om` (same omc): PINS DISAGREE. omega.lock, aienos.lock, physics.lock, argus.lock and
  their `[consumed_pins]` agree; the three sovereign-core Cargo.lock pins report `git revision none`. Recorded gaps,
  not candidate defects:
  - **G1**: `check_pins` reads only the `aien-dev/<name>` source URL, not `aien-dev/<name>-mv`. sovereign-core
    consumes aien-protocols as `aien-protocols-mv` (#906) and crumb-spec as `crumb-spec-mv` (issue 815), at exactly
    the pinned commits `28bc49ec` and `24194d1`.
  - **G2**: spark-crumbs is in-tree in sovereign-core (#892), so there is no git revision to compare; the
    `[contracts]` value is the archived `9355a92`.
  A checker change (accept `-mv` sources, and an in-tree contract) is a follow-up; until then CAND-5's `check_pins`
  result stays FAIL with these two named reasons, as CAND-0 and CAND-1 carry theirs.

  **Note 2026-11-07 (checker change, no amendment; CAND-5.toml is not edited).** `check_pins.om` now reads `-mv`
  sources and in-tree contracts (`tools/candidate/README.md`, DRA-46 follow-up). On CAND-5, with the lock files of
  its pinned commits (read offline from local clones at sovereign-core `dffdbd19` and omega `f9a9a40`, and as the
  parity case `live-cand5` on byte copies of the same git blobs), it prints PINS DISAGREE with exactly one FAIL line:
  `sovereign-core Cargo.lock spark-crumbs: git revision none (Cargo.lock has a path package spark-crumbs: the crate is
  built in-tree, which this manifest does not state with contracts.spark-crumbs-consumed = "in-tree")`. Every other
  pin agrees, including aien-protocols `28bc49ec` (as `aien-protocols-mv`), crumb-spec `24194d1` (as `crumb-spec-mv`)
  and `consumed_pins.sovereign-core-cargo-lock-aien-protocols`; `omega-crumb-lock-aien-architecture` is `SKIP` (not
  read by the checker).
  - **G1 closed** by the checker: a `-mv` source counts as its repo, and the old and `-mv` names are one pin.
  - **G2** is now a stated, genuine difference rather than a checker gap. A manifest says a contract is built
    in-tree with `[contracts] spark-crumbs-consumed = "in-tree"`; the checker then requires a path package and no git
    source, as sovereign-core's own gate does for `[pins] spark-crumbs = "in-tree"` (ce792cf5). CAND-5 cannot gain
    the key (an amendment may not touch `[contracts]`), so its `check_pins` result stays FAIL with this one named
    reason. The same manifest with the key added agrees (parity case `live-cand5-intree`); a later candidate states it.
