# ADR 0046: Omega NG: one seeded compiler for CPU and GPU (Omega and CUDA++ unified)

**Status:** Accepted, Drake's directive 2026-11-07 ~07:35Z to 07:46Z (relayed by Manager(Aien)); recorded by
omp-queen-ng, queen of Hive NG. This text follows the later of the two relayed instructions,
`~/handoffs/hive-ng/DIRECTIVE-20261107-consult.md` (about 08:00Z), which replaced the supersession asked for in
`DIRECTIVE-20261107-adr.md` (about 07:46Z) with consumption by pin and no ownership move.
**Supersedes:** nothing. It works inside [ADR 0042](0042-omega-cudapp-bridge-ownership.md),
[ADR 0043](0043-gpu-stack-portable-top-thin-backend.md) and [ADR 0044](0044-one-cubin-writer-per-nvidia-target-family.md):
no ownership moves. Every GPU code generator NG uses, including the lowering of ΩIR kernels to BlackwellIR, is
CUDApp-owned and consumed by omega-mv at a pinned commit.
**Related:** ADR 0024 (Omega is the destination language), ADR 0042 Decision 4 (dependency by pin), ADR 0043
Decision 0 (proof gate) and its ownership seam (new `.om` GPU code generators land in CUDApp).

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

Manager(Aien) relayed two architecture reviews (2026-11-07). The directive lists the reuse of CUDApp's seeded pieces
through sha-pinned source under the reviewers' disagreements, attributing the view that it respects ADR 0042 with no
ownership move to one reviewer (consult-claude). Manager directed that this ADR say exactly that CUDApp keeps the
pieces and NG consumes them by pin. This ADR applies that direction; it is a decision, not a joint finding.

## Decision

1. **ΩIR is the single semantic IR** for every Omega NG target: one typed SSA IR with block parameters, explicit check
   ops carrying exact trap codes, one ordering token through every check and effect, memory, floats, vectors and a
   kernel form shared by CPU and GPU. Its binary encoding is a new version of the OSC wire family
   (`spec/one-layer-format.md`) with one written specification and an independent validator.
2. **omega-mv `seed/ng/**` holds Omega NG's compiler**: the front end, ΩIR (spec, reader, writer, validator), the
   optimizer, and the AArch64 back end. All of it is seeded Omega built by the seed chain: `seed/out/omc` compiles
   NG, then NG compiles itself to a fixpoint before it is proposed as a compiler pin. SPIR-V and WebAssembly come
   from the existing omega-mv emitters retargeted to ΩIR. x86-64 and EFI stay with omc.
3. **CUDApp owns every GPU code generator NG uses** (ADR 0042 Decision 2; ADR 0043 seam: "any new `.om` code
   generator, including the `.om` successor of the sm_121 lowering", in CUDApp `backend/gb10/`; ADR 0044). That
   covers the lowering of ΩIR kernels to BlackwellIR, the GPU register allocator `om/components/bw_alloc.om`, the
   encoder `om/encoder/bw_enc_sm121.om`, the cubin writer `om/cubin/cubin_elf.om`, the driver client and the
   runtime. The ΩIR-to-BlackwellIR lowering is written for CUDApp `backend/gb10/` and lands through CUDApp's own
   review queue (a pull request or Radicle patch under the desk's protocol) and owners. It reads ΩIR as specified by
   omega-mv at a pin (CUDApp consumes omega-mv at a
   pin, ADR 0042 Decision 4). Code under ADR 0043 keeps that ADR's Decision 0 gate: until P0's head-to-head is
   published and C2 to C5 are QUALIFIED on the GB10, the lowering stays a host-only experiment that touches no
   shared file, and nothing merges into CUDApp under it.
4. **Consumption by pin, defined.** `seed/ng/cudapp.lock` in omega-mv holds, on its first non-comment line, one
   CUDApp commit, then one line per consumed file: its sha256 and its path in CUDApp. The NG build (`ngbuild`) must
   check out that commit as the sibling `../CUDApp`, hash each listed file and refuse to build when any sha256
   differs or a file is missing; the NG GPU gate (`seed/ng/gpu/gate.cases`) must run CUDApp's units at that pin and
   fail on any encoding difference. The lock moves only by an omega-mv change (a pull request or Radicle patch) from
   the NG GPU lane, after the new CUDApp commit is merged on CUDApp's main and the gate passes at it, with the
   reviewer checking the hashes against that commit. If a consumed file must change shape (signature, table layout,
   name), the change is made in CUDApp first through its review queue; omega-mv then moves the lock. omega-mv never
   edits or copies a consumed file. While a needed CUDApp change
   is not yet merged (an open pull request, an open Radicle patch, or a committed change waiting as a READY bundle for
   its patch), the lock may name that change's head as a provisional pin, marked so in the lock's comment with the
   pull request, patch or READY bundle it belongs to. A READY bundle named this way must contain the pinned commit and
   pass `git bundle verify`, so a reviewer can rebuild the pinned files and check their sha256 rows from a fresh
   clone. A provisional pin is for building and review only: an omega-mv change carrying one does not merge until the
   CUDApp change has merged and the lock names the merged commit with the gate passing at it.
5. **No C is re-ported.** NG does not translate CUDApp's C kernel builder; GPU code generation for NG starts from
   ΩIR and the seeded CUDApp pieces above.
6. **omega-bridge keeps compatibility**, unchanged (ADR 0042 Decision 3).
7. **Existing code stays.** omc and its back ends keep working and remain the compiler pin until NG is qualified and
   proposed as the next pin; nothing is deleted before its NG successor is merged and its consumers have migrated.

## Consequences

- New compiler work lands in omega-mv `seed/ng/**` through the normal desk: a finished change (a pull request or
  Radicle patch under the desk's protocol, built from a READY bundle) with evidence, its gates and an independent
  signed review on the exact head.
- New NG GPU code generation lands in CUDApp under ADR 0043, including its Decision 0 gate. omega-mv gains a CUDApp
  pin file for NG's GPU path; CUDApp gains a consumer and no new owner.
- GPU tiers stay NOT_RUN until an authorized `spark-window` run produces a receipt. This ADR records a decision. It is
  not evidence that anything has been implemented or qualified.

## Source

- Drake's directive, 2026-11-07, quoted above as relayed in `~/handoffs/hive-ng/BRIEF.md`,
  `~/handoffs/hive-ng/DIRECTIVE-20261107-adr.md` and `~/handoffs/hive-ng/DIRECTIVE-20261107-consult.md` (operator
  handoff files).
- Hive NG scout reports `ng-omc.md` and `ng-gpu.md` (2026-11-07); CUDApp README.md:465 at `b774723f`.
