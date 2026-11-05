# ADR 0044: One cubin writer per NVIDIA target family, owned by CUDApp

**Status:** Accepted (Drake, 2026-10-30).
This ADR moves no code.
**Related:** ADR 0042 (ARCH-0042) Decision 7, ADR 0043 call 15 (merged #343; CUDApp pin `780a0af1`).
[CUDApp#108](https://github.com/aien-dev/CUDApp/issues/108) tracks consolidation.
[CUDApp#170](https://github.com/aien-dev/CUDApp/issues/170) rebases onto this layout.
[CUDApp#190](https://github.com/aien-dev/CUDApp/pull/190), merged 2026-10-30 as `78fea51d`, added the inventory `docs/CUBIN_WRITERS.md`.
[omega-mv#864](https://github.com/aien-dev/omega-mv/pull/864) holds `seed/sm80/cubin.om`.

---

## Context

On CUDApp main `d79519e0` the sm_121 ABI 8 writer is one writer with two bodies (inventory:
`docs/CUBIN_WRITERS.md`, added by [CUDApp#190](https://github.com/aien-dev/CUDApp/pull/190)). `src/omega_cubin.c` writes the
container only: it opens no device and performs no launch. The hosted build packs through
`om/cubin/cubin_elf.om`. The C body is slated for deletion. ADR 0043 call 15 cites the older
CUDApp pin `780a0af1`, where the GB10 column of `ob_code_load` names `omega_cubin.c` for cubins.

omega-mv `seed/sm80/cubin.om` exists only on closed draft omega-mv#864. It accepts SM 80, 86,
87, 89, 90, 100, 103, and 120, and it refuses 121. The body of
[omega-mv#864](https://github.com/aien-dev/omega-mv/pull/864#issue-6050605672) reports libcuda
load PASS lines: vecadd/ctl PASS on an RTX 4090 (sm_80/86/89), a B200 (sm_100), and an RTX 5090
(sm_120). Those lines are reported by that PR and were not independently re-run for this ADR.
The same body reports what did not pass: the cubin without `.note.nv.tkinfo` still LOAD_FAILs
(200) on sm89 and sm120; sm_103 is NOT_RUN; sm_90 ABI 8 is NOT_RUN (the H100 hosts had driver
550), while sm_90 ABI 7 vecadd/ctl PASS; the alu.s2 schedule race (WRONG/700 on sm89) is open.
sm_87 is in the accepted list but has no load line.

ADR 0042 (ARCH-0042) makes CUDApp the owner. Decision 7 requires a separate consolidation
decision by Drake. This ADR records that decision (option B, 2026-10-30). ADR 0043
does not cover the sm_80 family.

## Options

The count is the one in CUDApp `docs/CUBIN_WRITERS.md` (CUDApp#190): two bodies of the sm_121 writer, plus `cubin.om`.

- **A.** Keep both bodies and keep `cubin.om`.
- **B.** `cubin_elf.om` is canonical.
- **C.** `omega_cubin.c` is canonical.

## Decision

Option B. One cubin writer per NVIDIA target family, owned by CUDApp.

CUDApp owns all cubin writing, the sm_80 family included, under `backend/<target>/`. The
NVIDIA `backend/<target>/` directory does not exist on CUDApp yet. It is created when the
work moves. New writer work goes only into `.om`. `omega_cubin.c` is frozen, and it is
retired only after the `.om` writer produces byte-identical sm_121 cubins and loads on GB10.
That removal is a later, separate PR. The source names a different trigger: the header comment
of `src/omega_cubin.c` (CUDApp main `183fa4f1`, line 18) says the C body "is deleted once the
freestanding binding lands". The two conditions differ. The freestanding binding is a build
prerequisite, because the freestanding build (`OMEGA_GPU_NO_POSIX`) still packs through the C
body (`docs/CUBIN_WRITERS.md`, writer row C). Retirement also needs this ADR's condition. This
ADR does not edit that comment.

omega-mv#864's ABI 8 and register-reserve findings are ported into CUDApp as new work. No
writer stays in omega-mv except a declared, pinned oracle (ADR 0042 Decision 4). CUDApp#170
rebases onto this layout.

## Consequences

CUDApp#108 tracks consolidation. ADR 0042 Consequences names each owner's issue as the place a
later consolidation decision is recorded; for the cubin writer that issue is
[CUDApp#108](https://github.com/aien-dev/CUDApp/issues/108), and this ADR is that decision.
The inventory is CUDApp `docs/CUBIN_WRITERS.md`, added by merged PR CUDApp#190. It records the
tkinfo difference on sm_121 ABI 8 and the stored register count; that open work is tracked in
CUDApp#108 (its REGS+2 and tkinfo findings, "Done when" 3).
The alu.s2 race issue is [CUDApp#191](https://github.com/aien-dev/CUDApp/issues/191). Hardware tiers stay NOT_RUN until an authorized window.
This ADR moves no code.

## Source

- ADR 0042, merged as #342. Decision 7 requires the separate consolidation decision recorded here.
- ADR 0043, merged as #343 (`a0a7146`). Call 15 (`ob_code_load`) cites CUDApp `780a0af1`.
- CUDApp main `d79519e0`: `src/omega_cubin.c` and `om/cubin/cubin_elf.om`.
- CUDApp#108, CUDApp#170, CUDApp#190 (merged as `78fea51d`; `docs/CUBIN_WRITERS.md` on CUDApp main `183fa4f1`).
- omega-mv#864, `seed/sm80/cubin.om` on `ck/cubin-om` (`76639738`).
