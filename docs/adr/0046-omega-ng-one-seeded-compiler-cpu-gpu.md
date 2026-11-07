# ADR 0046: Omega NG: one seeded compiler for CPU and GPU (Omega and CUDA++ unified)

**Status:** Accepted, Drake's directive 2026-11-07 ~07:35Z to 07:46Z (relayed by Manager(Aien) in
`~/handoffs/hive-ng/DIRECTIVE-20261107-adr.md` and `DIRECTIVE-20261107-consult.md`; recorded by omp-queen-ng, queen
of Hive NG).
**Supersedes:** nothing. It works inside [ADR 0042](0042-omega-cudapp-bridge-ownership.md),
[ADR 0043](0043-gpu-stack-portable-top-thin-backend.md) and [ADR 0044](0044-one-cubin-writer-per-nvidia-target-family.md):
no ownership moves. Omega NG consumes CUDApp's seeded Omega GPU pieces at a pinned commit.
**Related:** ADR 0024 (Omega is the destination language), ADR 0042 Decision 4 (dependency by pin).

---

## Context

Drake's words on 2026-11-07, verbatim:

- "I want everything written in pure seeded omega. If the compiler is too slow to outrun the other languages,
  then you need to create the next generation of Omega Compiler."
- "Don't let what I've told you in the past restrict your creativity for the future. Evolve Omega and CUDA++
  into something greater, something more uniform, semantic, and universal across everything. It can compute
  with no matter what it is. Evolve this compiler into the ultimate thing." / "use all of my repos to evolve
  this thing into something beautiful" / "Absolutely no restrictions. Do it however you think is best to do it.
  Make no mistakes."
- "You can run the GPU. Just use your Omega language to do it."
- "CUDA++. Do it yourself. … Just make this fucker fly."
- "everything comes from the original handwritten kernel of the Omega language, which was hand-seeded,
  assembled, and compiled over and over again by my own agents. Whatever we build has to use that language to
  make it as fast as possible. Do whatever you need to do to make that happen. You can mutate the language, use
  the language in some other way, or take good things from other people's languages and implement them in our
  own languages. Figure it out please."

Ground truth (omega-mv main `943d955531b9d4d9f70deb41756c0b46441dd5e0`, CUDApp main
`b774723f537cec16a359fe082b8100317a5b5490`, checked 2026-11-07):

- omega-mv's seeded compiler `seed/omc/omc.om` emits AArch64 directly with no IR on the native path, a fixed
  16-register pool without spilling (error 12) and save-all calls. Its IR mode writes scalar-only OSC IR v1.
- CUDApp already holds seeded Omega GPU pieces: the sm_121 encoder `om/encoder/bw_enc_sm121.om`, the cubin packer
  `om/cubin/cubin_elf.om` and the allocator component `om/components/bw_alloc.om`. Its kernel builder
  (`src/omega_blackwell_codegen.c`) and runtime are C.
- CUDApp's README (line 465 at `b774723f`) applies ADR 0042 this way: "The existing Omegese → IR → sm_121 lowering,
  its checker and host words stay in omega-mv." The seeded port of that lowering (`seed/oscgpu/gpulow.om`,
  `gpuemit.om`) is on omega-mv draft #1044, which waits for a YubiKey re-sign of the checker.

Two independent architecture reviews (2026-11-07, relayed by Manager(Aien)) found that a unified compiler does not
need an ownership change: reusing CUDApp's seeded pieces through sha-pinned source keeps ADR 0042 intact.

## Decision

1. **ΩIR is the single semantic IR** for every Omega NG target: one typed SSA IR with block parameters, explicit check
   ops carrying exact trap codes, one ordering token through every check and effect, memory, floats, vectors and a
   kernel form shared by CPU and GPU. Its binary encoding is a new version of the OSC wire family
   (`spec/one-layer-format.md`) with one written specification and an independent validator.
2. **omega-mv `seed/ng/**` holds Omega NG**: the front end, ΩIR, the optimizer, the AArch64 back end, and the lowering
   of ΩIR kernels to the input of CUDApp's encoder (the omega-mv side of the line CUDApp's README draws). All of it is
   seeded Omega built by the seed chain: `seed/out/omc` compiles NG, then NG compiles itself to a fixpoint before it
   is proposed as a compiler pin. SPIR-V and WebAssembly come from the existing omega-mv emitters retargeted to ΩIR.
   x86-64 and EFI stay with omc.
3. **CUDApp keeps owning GPU execution**, including the encoder, the GPU register allocator, the cubin writer, the
   driver client and the runtime (ADR 0042 Decision 2, ADR 0044). Omega NG consumes `bw_enc_sm121.om`,
   `cubin_elf.om` and `bw_alloc.om` from CUDApp at a commit pinned in omega-mv (`seed/ng/cudapp.lock`), the same
   pattern omega-mv uses for `om/omega-bridge.lock`. If a CUDApp piece must change shape for NG, the change goes
   through CUDApp's own pull-request queue and its current owners.
4. **No C is re-ported.** NG does not translate CUDApp's C kernel builder; GPU code generation in NG starts from ΩIR
   and the seeded pieces above.
5. **omega-bridge keeps compatibility**, unchanged (ADR 0042 Decision 3).
6. **Existing code stays.** omc and its back ends keep working and remain the compiler pin until NG is qualified and
   proposed as the next pin; nothing is deleted before its NG successor is merged and its consumers have migrated.

## Consequences

- New compiler work lands in omega-mv `seed/ng/**` through the normal desk: finished PRs with evidence, green CI and
  an independent review on the exact head.
- omega-mv gains a CUDApp pin file for NG's GPU path; CUDApp gains a consumer and no new owner.
- GPU tiers stay NOT_RUN until an authorized `spark-window` run produces a receipt. This ADR records a decision. It is
  not evidence that anything has been implemented or qualified.

## Source

- Drake's directive, 2026-11-07, quoted above as relayed in `~/handoffs/hive-ng/BRIEF.md`,
  `~/handoffs/hive-ng/DIRECTIVE-20261107-adr.md` and `~/handoffs/hive-ng/DIRECTIVE-20261107-consult.md` (operator
  handoff files).
- Hive NG scout reports `ng-omc.md` and `ng-gpu.md` (2026-11-07); CUDApp README.md:465 at `b774723f`.
