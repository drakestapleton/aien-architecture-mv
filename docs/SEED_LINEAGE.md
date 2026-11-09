# Seed lineage: where every running artifact comes from, and what would birth it from seed-0

Status: inventory, 2026-10-19. Ledger L107. This is a planning and evidence document, not a claim that any rung beyond the ones named in the seed brief exists.

Decision it serves (Drake, 2026-10-19, binding): one language rules the whole system, CPU, GPU, memory and storage. Every process on a machine is to be born from one seed. The seed is the chain being built on omega branch `seed/birth` (ledger L103): a hand-written hex seed, then labels, then a text-table assembler with CPU and GPU instruction tables, then an Omegese-to-words translator, then Atlas reborn. Today's tools (gcc, rustc, GNU as and ld) become reference oracles, then leave.

Sources: GitHub default branches read on 2026-10-19 at omega `a8ffd2b9`, physics `14273c5`, atlas `6b11395` (branch `master`), aien-sovereign-core `10b4f851`, aienos `18e2765`. Line counts are `wc -l` of source files (c, h, s, S, rs, sh, ld), excluding vendored NVIDIA headers, `vendor/`, `evidence/`. Totals that I added up carry an aien-calc receipt. Nothing was built or run for this document. Where a fact came from memory notes and could not be read from a source file, it is marked UNVERIFIED.

Terms used once: **rung** = one step of the seed chain. **Oracle** = the outside tool whose output I compare mine against. **OSC** = Omega Systems Core, the small systems language the compiler in omega `src/compiler` accepts. **Omegese** = the word-style program language in omega `docs/one_layer/OMEGESE.md`.

## 1. The lineage rule

Every artifact that runs declares its birth chain: which tool made it, which tool made that tool, and so on back to seed-0, the few hundred bytes written by hand as hex words.

An artifact built by an outside toolchain today is **on loan**. It carries the gate that will replace the loan:

1. My chain rebuilds the same artifact from the same source or listing.
2. The output is byte-identical to the outside build on a fixed corpus (for a program: the same bytes out for the same inputs; for a binary: the same bytes).
3. Only then does the outside tool leave the build. It stays archived as the oracle, so any later disagreement can be checked against it.

If my bytes and the outside bytes differ, the machine's manual (the ARM Architecture Reference Manual for CPU words, the sm_121 disassembler for GPU words) decides, and the difference is recorded either way.

Rungs, as defined in the L103 brief:

| Rung | What it is | Can express |
|---|---|---|
| 0 | seed-0, hex words, reads hex text and writes bytes | nothing but bytes |
| 1 | hex1, adds labels and one relative branch | hand assembly with names for places |
| 2 | text-table assembler, CPU table (name to bit pattern) | all of assembly, as readable text |
| 3 | Omegese subset to words: `fn`, `=`, `add sub mul and or`, `if/else/end`, `while ... bound`, `ret`, unsigned ints only | single functions on whole numbers, no arrays, no memory, no I/O |
| 4+ | a fuller Omega: bytes, aggregates, bigger storage, recursion, output | needs the language gaps in section 4 |
| 5 | Atlas reborn through rung 2 (ledger L105) | the 1,480-byte boot seed |
| 6 | sm_121 (Blackwell, the GB10 GPU) table in the rung-2 assembler (ledger L106) | GPU instruction words from a text listing |

## 2. The inventory

Machines: **S** = the Spark (DGX Spark, GB10), **I** = the iMac (AIENOS kernel, x86-64), **P** = the Pi 5 hub, **Q** = QEMU only so far.

"Under it" is what runs beneath the artifact that I did not write. "Rung" is the earliest rung that could birth it: `2` assembly text only, `6` GPU words from a listing, `NEW: <features>` needs language features that do not exist yet (section 4). No whole artifact is birthable at rung 3: rung 3 has no arrays, memory or I/O.

### 2.1 Boot and hardware layer

| # | Artifact | Repo | What it does | Lang | Lines | Built today by | Under it | Rung |
|---|---|---|---|---|---|---|---|---|
| 1 | Atlas boot seed (`atlas.bin`, 1,480 bytes) | atlas | Checks the next boot stage by SHA-256, hands over or halts | AArch64 asm | 509 (atlas.s 129, sha256_clean.s 319, physics_0.s 61) | GNU as (per L103 brief; the repo holds the committed bytes and no assemble step) | QEMU virt firmware; no native run yet | 2 (it is the rung-5 job, ledger L105) |
| 2 | Atlas gate tooling | atlas | Audits the bytes, mutates them, runs QEMU matrix | C, sh | 1,485 (calc:703b8874) | gcc | Linux, QEMU | NEW: bytes and strings, file I/O, process spawn |
| 3 | PHYSICS boot stages and effects (M2, M3) | physics | Verified boot stage after Atlas, capability and receipt code | AArch64 asm | 2,557 (physics.s plus m3/*.s; test .s inside) | aarch64-linux-gnu gcc, ld, objcopy (`m2_build.sh`) | QEMU virt firmware | 2, plus a hand-hex image header in place of `ld` |
| 4 | PHYSICS gate tools (m2tool, m15tool, scripts) | physics | Audit and qualify the boot artifacts | C, sh | 1,120 + 701 + shell | gcc | Linux | NEW: bytes and strings, file I/O |
| 5 | FORGE | physics | Realizes a verified Omega meaning, descriptors, analog simulator | C | 3,935 | gcc | Linux, libc | NEW: aggregates, bytes, and floating point if the analog simulator uses it (UNVERIFIED, not read) |
| 6 | GB10 client (`nvrm/`, `m16/`) | physics | Opens the NVIDIA device, allocates, maps memory, submits work | C | 2,354 (calc:9fa24296) | gcc | Linux 7.0.0-1019-nvidia, NVIDIA open kernel module 580.173.02, GSP firmware (section 4.2) | NEW: system calls (open, ioctl, mmap), layouts that match 37,334 lines of NVIDIA headers, pointers into mapped memory |

### 2.2 Omega (the language, compiler and GPU engine)

| # | Artifact | Repo | What it does | Lang | Lines | Built today by | Under it | Rung |
|---|---|---|---|---|---|---|---|---|
| 7 | OSC compiler and language front end | omega | Turns OSC source into AArch64 words | C | 11,346 (calc:612b5cdc) | gcc | Linux, libc | NEW: bytes and strings, large growable storage, recursion, output (OSC-1 reasons 1, 3, 4, 5) |
| 8 | AArch64 encoder and decoder | omega | Words from operands, operands from words | C | 592 | gcc | none | encoder: replaced by the rung-2 table, kept as oracle. Decoder: NEW: tables, bytes |
| 9 | Omega core: canonical form, validate, codec, program, verify, synthesis, library, discovery, machine, vector, matvec, evidence, receipt | omega | Meaning, proof and receipt machinery | C | 15,792 (calc:51a1ad52) | gcc | Linux, libc | NEW: bytes, aggregates, hashing, growable storage |
| 10 | Omega numeric | omega | Bit-exact reference arithmetic, reductions, tables | C | 6,411 | gcc | none beyond libc | NEW: floating point or exact integer emulation of it, wide multiply, tables |
| 11 | GPU code generators (`omega_blackwell_codegen*`, encoder) | omega | C programs that emit sm_121 words for each kernel family | C | 8,820 (calc:d8cb70e3) | gcc | none | NEW: loops over parameters, arrays, word output |
| 12 | GPU kernels as emitted words | omega | The attention, GEMM, MoE, router, decode and prefill kernels that run on the chip (about 14 families, one per codegen file) | sm_121 words | not text today; generated at run time | my own codegen (itself built by gcc) | GSP firmware, GPU hardware | **6** |
| 13 | GPU host and engine (`omega_gpu_*`, blackwell engine, submit, QMD, realize, matmul, gates) | omega | Command lists, launch descriptors, memory, waits, serving glue; ships as `libomega_gpu.a` | C | 16,100 (calc:d4e90cf7) | gcc, archive pinned by digest in sovereign-core `native-artifacts.lock` | Linux, NVIDIA module, GSP firmware | NEW: system calls, aggregates, volatile memory access |
| 14 | checker2 | omega | Independent checker for realization receipts, LRAT proofs | C | 3,382 | gcc | libc | NEW: bytes, growable storage, hashing |
| 15 | Runtime composition library (`src/runtime`, `librx_compose.a`) | omega | Graph, plan, route, cost model, operators, capability queue | C | 35,613 | gcc, archive pinned by digest | libc | NEW: nearly everything in section 4.1 |
| 16 | OSH shell core | omega | Lexer, parser, expander for the AIENOS shell | OSC + C references + sh | 5,174, of which 1,572 are OSC (`src/osh/*.osc`) | oscc (itself gcc-built) for the OSC part; gcc for the references | none | the OSC part is already in my language but is compiled by a gcc-built compiler, so it is born when OSC-14 self-host lands; the rest NEW |
| 17 | Omegese translator, `omega_emit`, `omega` CLI | omega | Omegese to IR to words; the one-layer path | C | Omegese 2,169, omega_emit 782, typediff 205, others | gcc | libc | the translator is itself the rung-3 product; its C original stays as oracle |
| 18 | Research and experiment subsystems: visor, turing, estimation, searchtrace, dual, ans, tensor, train, autodiff, algebra, fabric, reservoir, polyglot, physics0, crumbline, allen, path | omega | Experiments and gates the program is judged by | C, a little asm | 40,235 (calc:48327d02) | gcc | libc | NEW; lowest priority, rebirth only when something in the serving path needs them |
| 19 | Omega gate and chip-run scripts | omega | Run the gates and the chip tests | sh | 13,604 | not built; run by bash | bash, coreutils | NEW: the OSH shell (#16) must run first |

### 2.3 AIENOS (kernel and storage)

The local `~/workspace/aienos` is a docs-only copy; these numbers come from the GitHub main snapshot. The iMac lab drivers that are not on main (PR #415, #421) are not counted here (UNVERIFIED, from memory notes).

| # | Artifact | Repo | What it does | Lang | Lines | Built today by | Under it | Rung |
|---|---|---|---|---|---|---|---|---|
| 20 | AIENOS kernel (`native/kernel`) for Spark, Pi 5 and iMac | aienos | Memory, traps, devices, services; arm64 plus a small x86-64 port (x86 2,901 lines, arm64 arch 1,056) | C, asm, sh | 67,200 (calc:ca49e87e); asm inside is 887 lines | aarch64-linux-gnu gcc, ld, objcopy, plus Rust static libraries linked in | S: platform UEFI firmware. P: VideoCore firmware and the UEFI build in `rpi5-uefi`. I: Apple firmware (section 4.2) | asm part: 2. The rest: NEW: privileged instructions and system registers, volatile device memory, interrupt entry, inline words, all of 4.1. Last in order |
| 21 | EFI boot stage and slot loader (`native/boot`) | aienos | Loads the kernel image, signed A/B slot choice | C, asm, ld | 4,020 | gcc, ld | UEFI firmware | NEW: PE/COFF header as hand-hex words, bytes, signatures |
| 22 | Disk and NVMe path (`native/disk`, kernel `dev/nvme_*`, `disk_*`) | aienos | NVMe and SD block I/O, partitioning | C | 4,021 | gcc | NVMe controller firmware; none of mine | NEW: volatile device memory, DMA, bytes |
| 23 | Store (`native/store`) | aienos | Crash-safe artifact store: torn-slot handling, sealed records | C | 7,319 | gcc | the block device (#22) | NEW: bytes, aggregates, growable storage |
| 24 | Crypto and signatures (`native/crypto`, `native/sig`) | aienos | SHA-256, Ed25519 style checks | C | 2,698 (calc:3059d70b) | gcc | none | NEW, but the smallest: xor, shifts, rotates, 32 and 64-bit wrap, byte arrays |
| 25 | Capability, ARGUS, net, m5 | aienos | Authority tokens, defensive plane, network, small services | C | 25,894 (calc:1dbda6f3) | gcc | NIC firmware | NEW: all of 4.1 |
| 26 | AIENOS Rust crates (kernel model, boot, infer, store tool, others) | aienos | Host-side models and the two crates linked into the kernel image (`aienos-infer-kernel` 715, `aienos-capability-ffi` 768) | Rust | 72,716 (`aienos-kernel` alone 38,704) | rustc | Linux for host crates; none for the two kernel crates | NEW; Rust is scaffolding by project rule, so these are rewritten in Omega, not carried across |

### 2.4 Host runtime, the LLM path and tools

| # | Artifact | Repo | What it does | Lang | Lines | Built today by | Under it | Rung |
|---|---|---|---|---|---|---|---|---|
| 27 | `aien-serve-http` | aien-sovereign-core | HTTP front door: prompt in, tokens out | Rust | 4,664 | rustc | Linux sockets, libc | NEW: network and syscall effects, strings, bytes |
| 28 | Inference and runtime crates (`aien-inference-abi` 37,089, `aien-runtime` 24,381, `aien-cli` 15,431, kv-cache and kv-store 12,128, scheduler 3,455, nine `aien-omega-*` crates 7,979) | aien-sovereign-core | Session, scheduling, KV cache, model loading, calls into `libomega_gpu.a` | Rust | 100,463 for the crates named, source only (calc:9abf0f86) | rustc, plus gcc via `build.rs` for the omega archive | Linux, libc | NEW |
| 29 | `aien-test` (the Spark judge), `aien-local-ci`, `aien-verify` | aien-sovereign-core | Decide whether a change passes | Rust, sh | 20,047 Rust + 1,939 sh in `tools/` | rustc, bash | Linux, git, GitHub | NEW; moves after the OSH shell and the store |
| 30 | Other sovereign-core crates (spark-*, cortex-rs, crumbs, mcp, allen, security, trace, localhttp) and the Rust binaries copied to `~/.local/bin` | aien-sovereign-core, others | Mail, memory, supervisor, cockpit, harness | Rust | not summed | rustc | Linux | NEW; many are scaffolding that may simply retire |
| 31 | Shell tools in `~/.local/bin` (46 live scripts: ledger, gh guard, crumb, quiet-build, org-check, aien-watch, spark-cleanup and others) | no repo (home directory) | Coordinate agents, guard GitHub, run builds | sh | 3,218 | not built; run by bash | bash, coreutils | NEW: the OSH shell. Two files there are Python (`allen-vault`, `spark-receipt`), against the no-Python rule |
| 32 | Pi hub services I wrote: `readings-window` (503 Rust lines at local clone `bb39d99`), the `interplane` protocol crates (26,274 Rust lines), the `interplane.io` generator | readings-window, interplane, interplane.io | Serve GPU readings and the protocol page | Rust | 26,777 | rustc | Raspberry Pi OS Linux; headscale and nginx on the hub (UNVERIFIED, from memory notes of 2026-10-04) | NEW |

### 2.5 The LLM runtime path, prompt to GPU words

1. A prompt arrives at `aien-serve-http` (#27).
2. The Rust runtime (#28) tokenizes, schedules and manages the KV cache (the stored attention state), reading model weights as ordinary files through Linux.
3. It calls `libomega_gpu.a` (#13, C), pinned to an omega commit.
4. That library runs the generators (#11), which emit sm_121 words (#12) into GPU-visible memory.
5. `nvrm.c` (#6) opens the NVIDIA device and submits the work with `ioctl`.
6. Linux (7.0.0-1019-nvidia) and the NVIDIA open kernel module 580.173.02 carry the request; the GSP firmware blobs in `/lib/firmware/nvidia/580.173.02/` run on the GPU's own processor; the silicon executes.

Under my code the unwritten parts are: gcc and rustc, glibc, the Linux kernel, the NVIDIA module, the GSP firmware, the GPU. Only #12 is born from my own code today, and its generator (#11) was compiled by gcc.

### 2.6 What on PATH is not mine

`~/.local/bin` also holds outside programs (the coding agents `claude`, `codex`, `grok`, `agy`, `muse`; `rad`, `radicle-node`, `git-remote-rad`; `forgejo-runner`; `conduit`; `tectonic`; `bw`). They are not inventoried as my artifacts. They run on the machine and will run under whatever replaces Linux only if they are ported or retired. Not counted below.

## 3. Order of rebirth, with gates

Principle: smallest and purest integer code first; code that needs bytes, strings and I/O after the language gains them; the kernel last.

| Step | Artifact | Why here | Gate |
|---|---|---|---|
| 0 | seed-0, hex1, text-table assembler (L103 rungs 0 to 2) | everything else stands on these | each rung rebuilds itself byte-identical; every word reconciled against two decoders |
| 1 | Atlas, #1 (rung 5) | 1,480 bytes, all assembly, already audited word by word | `atlas.bin` byte-identical to sha256 `f7802501b410a0c19eff7b8fca8865c9ba9c96bfa4f8065ca8f508b67748b9a5`; the Atlas M1 gates pass in QEMU |
| 2 | PHYSICS boot stages, #3 | assembly only; needs the hand-hex image header that replaces `ld` | `physics.bin` and `atlas_m2.bin` byte-identical to the sha256 files in physics; M2 gates pass in QEMU |
| 3 | GPU kernels, #12 (rung 6) | same assembler, second table; the C codegen is the oracle | every emitted kernel word equal to the C codegen's, bit for bit; one kernel then run on the chip |
| 4 | First Omega words (rung 3) | proves the translator end to end on whole-number functions | the 10 public dev tasks return the same results as the C path; word-count table published either way |
| 5 | Crypto and signatures, #24 (with `sha256_clean.c` in Atlas and omega) | purest integer code, smallest, everything verifies against it | known-answer vectors plus a fixed corpus of inputs: digests and signature checks byte-identical to the gcc build |
| 6 | AArch64 decoder and the encoder fields, #8 | table-driven; the rung-2 table already supersedes the encoder | same words for every instruction form in `aarch64_encoder.h`; decoder returns identical text on a fixed word corpus |
| 7 | OSC compiler, #7 (OSC-14 self-host) | needed before any OSC code (#16) can be born without gcc | `compiler_n` built by `compiler_{n-1}` produces byte-identical output on a fixed corpus (omega determinism gate II.9) |
| 8 | Omega core, numeric, checker2, #9, #10, #14 | pure data code over bytes; the judges of everything above | same receipts and digests as the gcc build on the existing test corpus |
| 9 | GPU generators, #11, host and engine, #13, and `nvrm`, #6 | need system calls and volatile memory | same word streams and same submission traces as the gcc build; chip tests unchanged |
| 10 | OSH shell, #16, then the scripts, #19, #31 | shell tools can only be born once a shell is | each script's output byte-identical on a fixed run |
| 11 | Store, #23, storage drivers, #22, boot stage, #21 | need volatile device memory and DMA | torn-write and recovery tests identical; boot image byte-identical |
| 12 | Capability, ARGUS, net, #25 | large, rely on the above | existing gates unchanged |
| 13 | AIENOS kernel, #20 | 67,200 lines, privileged instructions, interrupts, device memory, and the only artifact that cannot be tested without hardware | kernel image byte-identical to the gcc build, QEMU gates, then native gates |
| 14 | Runtime, serve-http, judge and the rest, #26 to #30, #32 | these are Rust scaffolding by project rule; they are rewritten in Omega rather than re-compiled | behaviour and receipts identical to the Rust build on a fixed request corpus |

Research subsystems (#18) have no fixed place; they move when a needed part of the serving path depends on them.

## 4. Honest gaps

### 4.1 What the language cannot express today, by artifact class

Source: `docs/osc/OSC-1-SELF-HOST-STATEMENT.md` in omega, with its 2026-10-01 addendum. Its six reasons, and where they stand:

| OSC-1 reason | Status | Blocks |
|---|---|---|
| 1. No bytes, strings or text | open | every tool that reads a file or prints a line: #2, #4, #7, #9, #14, #16, #17, #21, #23, #27 and all shell |
| 2. No structs, unions or tagged data | superseded for structs by OSC-2 item 2 (omega#149) | still open for unions and tagged data |
| 3. No growable or large storage (arrays of 64, pool slots of 64 cells) | open | compiler tables (4,096 instructions per function), store, KV cache, runtime |
| 4. No recursion or forward calls | open | parser, compiler, shell |
| 5. No output channel (a program can only return a scalar; no I/O, capabilities or effects) | open | everything that talks to a device, a file or the network: #6, #13, #20 to #23, #27 |
| 6. No checked contracts | superseded by OSC-2 item 1 (omega#148) | none now |

Status of OSC-1 and OSC-2 is IMPLEMENTED / NOT QUALIFIED: host receipts only, not self-hosting, no production code compiled by either.

Further gaps from my reading of the inventory. These are UNVERIFIED against a language spec, confidence medium:

- **Rung 3 itself** has no xor, shift or array, and `uint` only. That is enough for the 10 dev tasks, not for crypto (#24), which needs xor, shifts and byte arrays. The Omegese table in `OMEGESE.md` section 3 does list `xor shl shr` and arrays; the rung-3 subset is narrower than the language.
- **Floating point** (#5, #10 and the tensor and autodiff subsystems in #18). Either a float type or bit-exact integer emulation is needed.
- **Machine-level access** for the kernel and drivers (#20 to #22): privileged and system-register instructions, volatile device memory, DMA, interrupt entry, and a way to place raw words inside a function.
- **A calling interface to code I did not write**, until it is all mine: the archives `libomega_gpu.a` and `librx_compose.a` and the Rust runtime call each other across the C ABI today.
- **Rust is not carried across.** #26 to #30 are rewritten, because Omega is the destination.

### 4.2 What sits below my code and no seed can replace

| Layer | Machine | Physical reason it cannot be birthed from the seed |
|---|---|---|
| GSP firmware (`gsp_*.bin`, loaded by the NVIDIA module; the GPU's own management processor) | S | The GPU runs it on a processor inside the chip and, to my understanding, accepts only NVIDIA-signed images checked by hardware keys fused into the chip. I hold no signing key, so I can send work to it but not replace it. UNVERIFIED here (no driver source line found in the physics snapshot saying so); confidence high. The physics repo's native driver path (`nvrm/`) talks to it through the Linux module. |
| GPU silicon boot ROM and memory training | S | Mask ROM and on-chip fuses: written at manufacture, read-only. |
| Spark CPU boot firmware (the early secure stages and platform UEFI) | S | The chip's first instructions come from vendor ROM that checks the next stage's signature. Atlas can be the first stage I choose only where the platform lets an owner-signed image run. Native Spark boot of AIENOS is parked (memory note, 2026-10-18). |
| CPU microcode | I | Loaded by the Intel CPU from vendor-signed blobs; the CPU rejects unsigned microcode. |
| iMac firmware (Apple UEFI, SMC, Intel management engine) | I | Vendor-signed and write-protected by hardware locks. Firmware replacement on the lab iMac is approved (Drake, 2026-10-18), but a read-only backup and a lock survey come first and no write code exists; whether the locks can be opened is not yet known. |
| Pi 5 boot ROM, VideoCore firmware, EEPROM | P | The Pi's first stage is mask ROM and VideoCore code from Raspberry Pi; my UEFI (`rpi5-uefi`) and Atlas start only after it. |
| Linux kernel and the NVIDIA open kernel module on the Spark and Pi hub | S, P | Not a physical limit: replaceable once AIENOS runs there. They sit under every Spark artifact today, which is why the Spark's serving path (section 2.5) cannot be fully mine yet. |
| Network and storage controller firmware (NIC, NVMe drive) | all | Inside each device and unreachable from the host. |

What the seed can reach is everything from the first instruction I am allowed to run upward: it cannot reach below the first signed vendor stage.

## 5. Counts

Counted from the tables above (rows 1 to 32; section 2.6 is excluded).

| Measure | Count |
|---|---|
| Artifacts total | 32 |
| Built today by an outside compiler or assembler (gcc, rustc, GNU as and ld) | 29 |
| Not built, run by an outside interpreter (bash) | 2 (#19, #31) |
| Built by my own codegen (which gcc compiled) | 1 (#12) |
| Birthable at rung 3 | 0 whole artifacts (rung 3 reaches single whole-number functions only) |
| Birthable at rung 2 (assembly text), including Atlas at rung 5 | 2 (#1, #3), plus the 887 assembly lines inside #20 |
| Birthable at rung 6 (GPU table) | 1 (#12) |
| Needing new language features | 29 |
| Cannot (physical reason) | 0 of my artifacts; 8 layers below my code listed in 4.2 |

Row check: 29 + 2 + 1 = 32 by build method, and 0 + 2 + 1 + 29 = 32 by rung. Calc receipts are shown as the first eight hex digits of the aien-calc id.
