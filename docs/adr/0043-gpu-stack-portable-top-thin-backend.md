# ADR 0043: The GPU stack splits into a portable Omega top and a thin per-target backend behind one 30-call ABI

**Status:** Accepted (Drake, 2026-10-30). Proposed 2026-10-27.
Design only. No code moves under this ADR until the gate in Decision 0 is met. Recorded by lane
SplitDesign.
**Related:** ARCH-0042 (ACCEPTED 2026-10-30, #342: Omega owns computation, CUDApp owns GPU execution, Omega
Bridge owns compatibility; Decision 2 superseded in part, see Decision 1), ARCH-0024 (Omega is the
destination language), ARCH-0018
(substrate-neutral realization). The companion file-level design is `docs/ARCHITECTURE.md` in
aien-dev/CUDApp (draft PR linked from this PR). **Merge order:** after ARCH-0042 (#342), whose
Decision 2 this ADR amends; if #342 changes first, this ADR is re-checked against its merged text.
**Inputs, all at pinned heads:** CUDApp main `780a0af1`; omega-mv main `e5b32567`; omega-mv
`omegese/gpu-front` `d1ac019e` and `omegese/gpu` `a99d711c`; the binding plan
`~/handoffs/GpuStack/PLAN.md` (phases P2–P4); the outside review Drake adopted
(`~/handoffs/ExternalReview/2026-10-27-review.md`); research notes
`~/handoffs/SplitDesign/filemap.md` and `c1path.md`.

---

## Context

CUDApp (CUDA++) runs LLM kernels on one chip, the GB10 (sm_121), through NVIDIA's open kernel module.
The outside review counted about 26k lines of C in CUDApp and about 35k lines of GPU C in omega-mv, and
answered "portable to AMD, Intel or Apple" with NO. PLAN.md orders the work: cut scope, prove the
numbers, generalize (P2), second backend (P3), integrate (P4). This ADR is the P2–P4 design.

What the code is today (CUDApp `780a0af1`, file and line evidence in `filemap.md`):

1. **Two backend tables already exist over the same driver client.** `OmegaGpuPlatform`
   (`src/omega_gpu_platform.h`, ABI 1.2, 22 function pointers, typed index+generation handles,
   separate CPU / GPU-VA / bus-address types) sits under the session and command list.
   `OmegaGpuBackend` (`src/omega_gpu_engine.h`, 15 ops, VECTOR_1D only) sits under the job engine.
   Neither covers kernel compilation or command encoding.
2. **The seam is in the wrong place.** `queue_submit` takes raw NVIDIA method words, so the QMD and
   pushbuffer encoding happens above it, in the "portable" files: `omega_gpu_cmdlist.c` (:199, :219,
   :226, :261) and `omega_gpu_session.c` (includes QMD/submit headers :18-19).
3. **Kernel definitions are C generators against a post-scheduling Blackwell IR.**
   `BlackwellIRInsn` carries sm_121 control words and scoreboards. Fifteen `omega_blackwell_codegen_*`
   generators plus inline emitters inside `omega_gpu_attention_api.c` and
   `omega_gpu_elementwise_api.c` define every LLM kernel. Seventeen API files include backend headers.
4. **Two files bypass the platform** and call `nvrm/` and `m16/` directly:
   `omega_blackwell_engine.c` and `omega_blackwell_submit.c`.
5. **One submission per token already exists for one model.** `decode_graph` records a whole
   Qwen3-30B-A3B token (436 launches over 48 layers) into one command list. That is 1 submit,
   1 doorbell, 2 marker waits and 1 retire. The CPU still writes about 1 KB of constants and 1 KB of
   QMD per launch ([INFERENCE] about 872 KiB per token into uncached memory).
6. **Weights are copied, not shared.** `omega_gpu_fp8_api.c:269-275` does `memcpy` then
   sync-to-GPU, although the GB10's memory is physically one LPDDR5X pool.
7. **The Omega-language path to the GPU (bar C1) is separate and NVIDIA-shaped.** On
   `omegese/gpu-front` the path is `tools/omegese/omegese.c` → `src/compiler/osc_ir.{h,c}` (IR v6, 37
   ops, 7 GPU-only) → `src/checker2/c2_check.c` (12 GPU rules) → `src/omega_osc_gpu.c` → the existing
   BlackwellIR encoder → `src/omega_osc_launch.c`. C1 is "BUILDING, chip FAIL" (2026-10-22: vadd
   896 wrong words with trap status 0, the GEMM launch hung, attention not run, cause undocumented).
   IR v6 bakes in a warp of 32, down-only shuffles, a 48 KiB shared cap, a 16-deep nesting cap tied to
   BSSY barrier registers, and transcendental semantics defined by MUFU. All of these stages except
   the IR text are C.
8. **Omega can already drive a device without C.** omc on omega-mv main `e5b32567` has `devctl`,
   `devcall` (RM_ALLOC / RM_CONTROL), `uvmctl` (an allowlist of 11 UVM requests from the 580.173.02
   ABI, including MAP_EXTERNAL_ALLOCATION and CREATE_EXTERNAL_RANGE), `mapnew`, `maphold`, `mapbind`,
   `mapget` and `mapset` (aligned 32/64-bit device-word access bracketed by DSB SY);
   `seed/host/MAPPING.md`. omc emits static AArch64 Linux ELF only. It has no way to call a C shared
   library, and its `devctl` allowlist covers only NVRM requests and FIONREAD.
9. **Non-NVIDIA reach today is SPIR-V and CPU only.** `irspirv.om` (merged; OpenCL SPIR-V on PoCL
   CPU), `vkspirv.om` (draft omega-mv #876: Vulkan GLCompute SPIR-V, lavapipe green in CI, MoltenVK on
   an M2 PASS, interim C launcher `vk-host.c`). No AMD, Intel, Apple-native or Qualcomm emitter exists.

PLAN.md's language rule binds the design: C imported from omega-mv moves unchanged; **new host-runtime
code is `.om`** (streams and events, multi-process sharing, the watchdog, the API implementation, the
scheduler, memory management); device kernels stay on the current encoder until C1 lands; any new C
needs a missing-feature reason with an extension proposal filed, behind a `migration-pending` build
switch.

## Decision

### 0. Gate: no code for P2–P4 before the proof

Code under this ADR starts only when P0 has published a same-box head-to-head and P1's bars C2–C5 are
QUALIFIED on the GB10. Until then only design documents, extension proposals and host-only experiments
that touch no shared file are allowed. This restates PLAN.md; it is not new policy.

### 1. The split

| Layer | Owns | Language | Lives in |
|---|---|---|---|
| **Portable top** | kernel definitions (Omegese), model graphs and scheduling (decode graph, batching), serving, the memory planner (weights, KV pool, scratch, serving reservation), streams/events, multi-process sharing, watchdog policy, the versioned public API | `.om` for all new code; the imported C top stays as migration | CUDApp |
| **Backend ABI** | the 30 calls in Decision 2 and the code-object formats in Decision 3 | defined once in `.om`; fixed field layout so receipts and the CPU reference backend can check it. The imported C stack is **not** retrofitted to it (that would be new C); it keeps `OmegaGpuPlatform` 1.2 until it is retired | CUDApp `backend/abi.om` (new) |
| **Thin backend, one per target** | driver client, command encoding (QMD/pushbuffer, AQL packets, Vulkan or Metal command buffers), code-object writer, per-target lowering and machine-code encoder, tuned kernels | `.om` for every new backend; the GB10 C backend is migration | new backends in CUDApp `backend/<target>/`; the existing GB10 C files stay where they are in `src/`, `nvrm/`, `m16/` and are classified, not moved |
| **Kernel IR, checker, front end** | Omegese, the kernel IR, checker2 | `.om` destination (omc's IR mode); the C front end on `omegese/gpu-front` is migration | omega-mv (ARCH-0042 Decision 1) |
| **Integrations** | ggml, vLLM, ONNX Runtime attachments | per-host language at the edge, calling compiled Omega through omega-bridge bindings | connected repos under omega-bridge (ARCH-0042 Decision 3) |

Ownership seam with ARCH-0042, **settled by Main's ruling of 2026-10-27** (recorded in
`~/handoffs/GpuStack/PLAN.md`, Rules → "Where code lives"): the existing C lowering in omega-mv (the
Omegese → IR → sm_121 path, checker2, host words) stays in omega-mv and is fixed there by lane C1Lang;
CUDApp consumes it at a pinned sha. Everything else in the GPU stack (driver client, kernels, runtime,
receipts) lands in CUDApp, as does any new `.om` code generator, including the `.om` successor of the
sm_121 lowering (`backend/gb10/`). The omega-mv copies of GPU runtime code are not deleted until the
cutover is proven; removal is a separate PR. Existing code is not moved or split between repos
(ARCH-0042 Decision 7).

**Supersedes, in part, ARCH-0042 Decision 2.** Where Decision 2 assigns "GPU code generators … the
register allocator and scheduling bits" to CUDApp, that clause does not cover the existing C sm_121
lowering of the Omegese → IR → checker2 path, which stays in omega-mv under the ruling above. The rest of
Decision 2 stands.

**In-process rule.** The top and a backend are linked into one program by omc (both `.om`), so a call
across the ABI is an ordinary Omega call. A `.om` top cannot call a C backend in-process today (fact 8).
Consequence: the imported C top and C GB10 backend keep running together as the migration path, and
the new `.om` top is built against a `.om` GB10 backend that uses the device words omc already has.
No `.om`-to-C shim is written to bridge them.

### 2. The backend ABI: 30 calls

`OmegaBackend` ABI 2.0 is the successor of both `OmegaGpuPlatform` 1.2 and `OmegaGpuBackend` in the
`.om` stack; the two C tables stay frozen under the imported C stack until it is retired. It keeps the 1.2
conventions that worked: typed handles (index + generation, 1024-slot table), separate CPU-view /
GPU-VA / bus-address types, rights bits, the GPU-uncached rule for host-polled words, and
`negotiate`/`check` before use. Host services (time, sleep, locks, host allocation) leave the backend:
the top gets them from Omega host words. All calls return a status code (`OK`, `REFUSED`, `NOMEM`,
`TIMEOUT`, `FAULT`, `LOST`, `UNSUPPORTED`); outputs go through out-parameters.

| # | Call | Contract | GB10 today (CUDApp `780a0af1`) |
|---|---|---|---|
| 1 | `ob_negotiate(abi_major, abi_minor, out table)` | refuse on major mismatch | `omega_gpu_platform_negotiate` (platform.c) |
| 2 | `ob_device_count(out n)` | enumerate devices of this backend | `omega_gpu_chip.c` /sys PCI table |
| 3 | `ob_device_open(index, out dev)` | open driver, create VA space and channel | `nvrm_open` + `m16_native_create_channel` (platform_linux.c `device_open`) |
| 4 | `ob_device_close(dev)` | release everything owned by the device | `m16_native_close` |
| 5 | `ob_device_caps(dev, out caps)` | target id, subgroup width, shared bytes, max grid, accepted code formats, unified-memory class, queue count, timestamp period | scattered constants (code_alloc.h, codegen limits); new struct |
| 6 | `ob_device_status(dev, out fault)` | fault/lost state and driver fault code | not exposed; nvrm event/Xid path [INFERENCE] |
| 7 | `ob_diag_text(dev, buf, n)` | bounded diagnostic text | `ref_diag_text` |
| 8 | `ob_mem_alloc(dev, bytes, flags, out buf)` | flags: DEVICE_LOCAL, HOST_VISIBLE, HOST_COHERENT, GPU_UNCACHED, CODE, READ_MOSTLY; returns handle + CPU view + GPU VA | `dma_alloc` → `nvrm_alloc_gpu_uncached` / `nvrm_alloc` |
| 9 | `ob_mem_import_host(dev, cpu_ptr, bytes, flags, out buf)` | zero-copy: map existing page-aligned host memory (an mmapped weight file) for the GPU without copying; `UNSUPPORTED` if the target cannot | none; fp8_api.c:269-275 copies |
| 10 | `ob_mem_free(buf)` | | `dma_free` → `nvrm_free` |
| 11 | `ob_mem_flush(buf, off, n)` | CPU writes visible to GPU | `sync_cpu_to_gpu` (dsb sy + L2 invalidate, omega#457) |
| 12 | `ob_mem_invalidate(buf, off, n)` | GPU writes visible to CPU | `sync_gpu_to_cpu` |
| 13 | `ob_mem_advise(buf, off, n, advice)` | prefetch, residency, read-mostly; advisory, never changes results | none (AIEN_OMEGA_DGRAPH_PREFETCH env only) |
| 14 | `ob_mem_info(dev, out stats)` | used, free, reserved, driver allocations since seal | serving reserve/seal stats (serving.c) |
| 15 | `ob_code_load(dev, code_object, out code)` | load one code object (Decision 3); validates format and resource metadata, refuses unknown | `session_alloc_code` + code copy; `omega_cubin.c` for cubins |
| 16 | `ob_code_info(code, out info)` | registers, shared bytes, argument layout, max threads | QMD fields in `omega_blackwell_qmd.c` |
| 17 | `ob_code_free(code)` | | `session_free` |
| 18 | `ob_queue_open(dev, flags, out q)` | flags: priority, shared-process | `queue_open` (one queue today) |
| 19 | `ob_queue_close(q)` | | `queue_close` |
| 20 | `ob_dispatch(q, code, dispatch)` | append one launch: grid[3], block[3], dynamic shared bytes, argument bytes, buffer bindings. **The backend encodes it**: QMD + constant bank on GB10, an AQL packet + kernarg on AMD, `vkCmdDispatch` on Vulkan, a compute encoder on Metal | `omega_gpu_session_launch` (session.c:445) and `emit_inline_qmd` (cmdlist.c:226) with its PCAS method words (cmdlist.c:308-309), moved below the seam |
| 21 | `ob_submit(q, out seq)` | ring the doorbell once for everything appended since the last submit | `queue_submit` → `m16_native_submit_methods` (1 GPFIFO entry + doorbell) |
| 22 | `ob_graph_begin(q)` | start recording dispatches into a replayable graph | `omega_gpu_cmdlist` record mode |
| 23 | `ob_graph_end(q, out graph)` | close the recording; the backend may pre-encode everything | cmdlist finalize |
| 24 | `ob_graph_launch(q, graph, patches, out seq)` | replay a graph with a small patch list (token position, KV length, buffer offsets) and one doorbell | `omega_gpu_cmdlist_submit`'s `queue_submit` call (cmdlist.c:325), which `decode_graph` replays through; per-token patching is new |
| 25 | `ob_graph_free(graph)` | | cmdlist free |
| 26 | `ob_fence_wait(q, seq, timeout_ns, out status)` | wait for completion; `TIMEOUT` and `FAULT` are results, not hangs | `poll_word` → `m16_native_wait_marker` |
| 27 | `ob_event_record(q, out ev)` | a point in a queue other queues or processes can wait on (C4 streams) | none (cmdlist stamps only) |
| 28 | `ob_queue_wait_event(q, ev)` | GPU-side wait, no CPU round trip | none |
| 29 | `ob_queue_reset(q)` | cancel outstanding work and restore a usable queue after a fault or a watchdog decision (C5) | `queue_retire` + session park; recovery is new |
| 30 | `ob_clock_ns(dev, out host_ns, out gpu_ticks)` | correlate host and GPU clocks for timing receipts | `time_now_ns` (host only) |

Rules on the ABI:

- **Raw method words never cross it.** That is the defect it fixes. `submit_prefix_words`, PCAS and
  INLINE modes, and the 5-word L2 invalidate prefix become GB10 backend internals.
- **Bypasses are retired.** `omega_blackwell_engine.c` and `omega_blackwell_submit.c` stop being
  called by the top; they stay in place as GB10-internal code (or are deleted at a cutover that
  replaces them). The `m16/` and `nvrm/` gate programs remain backend tests. Within CUDApp the split is
  logical (headers, build groups, CODEOWNERS), not a file move.
- **Versioning.** The public runtime API is ABI 0.1 today. Moving the STABLE
  `omega_gpu_session_launch` / `OmegaGpuLaunch` from raw code + QMD shape to a code object is a MAJOR
  bump (API.md §2). The decode-path APIs absent from the manifest today (fp8, fp8gemm, bf16_gemv,
  decode_attn, router, tern, tcgemm, prefill*, moe, decode_graph) enter the manifest as EXPERIMENTAL
  before any of them moves (CUDApp#124). API.md §2 counts an added EXPERIMENTAL entry as a MINOR
  change, so the first such entry bumps the API to 0.2 (MINOR) when it enters the manifest; no
  exception to API.md §2 is made.
- **A CPU reference backend** (AArch64, `.om`) implements the same 30 calls with code-object format
  `AARCH64`. It runs every top-level test on a GitHub `ubuntu-24.04-arm` runner without a GPU and is
  the negative-control target: a mutant kernel must fail there before any chip run is requested.

### 3. One kernel source: Omegese → kernel IR → checker2 → per-target lowering

Kernels are written once in Omegese. Bar C1's path becomes the only kernel source once C1 is QUALIFIED
on the GB10; the C generators stay as the tuned GB10 path and as the oracle for each kernel until its
Omegese version matches it on chip with identical golden tokens.

**IR v7 (proposal to omega-mv; v6 stays frozen for C1).** Make the NVIDIA-shaped facts per-target
parameters reported by `ob_device_caps`, not semantics:

- subgroup width as a parameter (32 on NVIDIA and Apple, 64 on CDNA, 32 or 64 on RDNA, implementation
  defined on Vulkan), with shuffles defined over the parameter and both directions;
- shared-memory budget as a parameter, refused by checker2 when a kernel exceeds the device's value;
- the nesting cap as a checker2 parameter, not a property of BSSY;
- transcendental ops defined by a stated accuracy class (correctly rounded / ≤ N ulp / fast), each
  target proving its class against the host reference;
- new: explicit address spaces (global, shared, constant), atomics, f16/bf16/fp8 types, and one tiled
  matrix-multiply-accumulate op with per-target lowering (HMMA/QMMA on sm_121, MFMA on CDNA, WMMA on
  RDNA 3/3.5, simdgroup matrix on Apple, cooperative-matrix or scalar on Vulkan).

The checker2 race and divergence rules are already target-generic and carry over unchanged. The
front end's destination is omc's own IR mode (OMEGESE §11, `.om`); the C front end
`tools/omegese/omegese.c` is migration.

**Per-target lowerings and code objects:**

| Target | Code object | Lowering path | Oracles (verification only, never in the build path) |
|---|---|---|---|
| GB10 sm_121 | `SM121_RAW` (code + launch metadata, today's form) | existing `omega_osc_gpu.c` → BlackwellIR → regalloc → encoder; `.om` port after C1 | NAK sources (MIT) + chip tests; `nvdisasm` as a read-only checker (C6) |
| AMD CDNA3 (gfx942) / RDNA3.5 (gfx1151) | `AMDGPU_HSACO` (ELF code object with HSA metadata notes) | **direct `.om` encoder** from AMD's published ISA reference guides, plus a `.om` HSACO writer | `llvm-mc --disassemble`, `llvm-readelf --notes`, reference kernels from `llc -mtriple=amdgcn-amd-amdhsa`, chip tests |
| Vulkan 1.3 compute | `SPIRV_VK` | `vkspirv.om` (draft #876) re-based on IR v7 | `spirv-val`, lavapipe, chip tests |
| Apple M-series | `MSL_SOURCE` | `.om` emits Metal Shading Language text; Metal's runtime compiler builds it at load | the same kernel through MoltenVK + SPIR-V; host reference |
| Qualcomm Adreno | `SPIRV_VK` via Mesa turnip | the Vulkan path | as Vulkan |
| CPU reference | `AARCH64` | omc's native path | host reference, Wolfram for constants |

Why the direct AMD encoder and not LLVM IR → `llc` in the build: an outside compiler in the build path
is a dependency that must be recorded with its replacement (harness rule), and AMD publishes the ISA, so
a direct encoder needs no reverse engineering. LLVM stays where `nvdisasm` sits for NVIDIA: an oracle
that checks our words. If the direct encoder blocks P3 for longer than a stated budget, `llc` may be
used as a disclosed, pinned, migration-pending build dependency by a later decision, not by default.

Apple honestly: AIR and the AGX ISA are undocumented, so the Apple backend emits MSL text and relies on
Apple's compiler. That is a platform dependency of the same kind as NVIDIA's kernel module, recorded
with its version. No AGX reverse engineering.

### 4. Unified memory is the edge

Three mechanisms, each a measurement target before any claim:

1. **Zero-copy weights.** The weight file is mmapped once; `ob_mem_import_host` maps those pages for
   the GPU. Weights appear once in physical memory and processes that share the file share the pages
   (this feeds C5 multi-process sharing).
2. **One submission per token.** The decode token is a recorded graph replayed with a patch list
   (`ob_graph_launch`), removing the per-launch QMD/constant rewrite (about 872 KiB per token
   [INFERENCE]).
3. **A resident whole-model kernel** (experiment, not a commitment): a persistent kernel reads a
   device-side work word per token from host-coherent memory. It is gated on watchdog and preemption
   behaviour per target and is dropped on any target where it cannot be cancelled by `ob_queue_reset`.

| Machine | Memory | Zero-copy import | One submission per token | Resident kernel |
|---|---|---|---|---|
| GB10 | 128 GB LPDDR5X shared, CPU–GPU coherent link | UVM external range on mmapped pages (`uvmctl` CREATE_EXTERNAL_RANGE / MAP_EXTERNAL_ALLOCATION are already allowlisted in omc); first task is a host probe of which path the 580.173.02 module accepts for file-backed pages [INFERENCE] | exists for Qwen3-30B-A3B via PCAS; add patching | host-polled word in GPU-uncached memory (existing rule); watchdog TBD |
| Apple M-series (M2 reachable) | unified LPDDR | `newBufferWithBytesNoCopy` on page-aligned mmap, shared storage mode | one command buffer per token; indirect command buffers for replay | not planned: the GPU watchdog kills long kernels [INFERENCE] |
| AMD Strix Halo (gfx1151 APU) | unified LPDDR5X | KFD SVM (`AMDKFD_IOC_SVM` set-attributes) or userptr allocation | N AQL packets written to the user-mode queue, one doorbell write | candidate; AQL queues allow long-running kernels [INFERENCE] |
| AMD MI300A (gfx942 APU) | unified HBM3 | KFD SVM with XNACK (`AMDKFD_IOC_SET_XNACK_MODE`) | as Strix Halo | candidate |
| AMD MI300X (gfx942 discrete) | separate HBM; **not unified** | copy path only; tests the backend and kernels, not the unified-memory edge | as Strix Halo | candidate |
| Qualcomm Snapdragon (Adreno) | unified LPDDR5X | `VK_EXT_external_memory_host` on turnip | reused Vulkan command buffers, one `vkQueueSubmit` | not planned |

KFD facts checked 2026-10-27 on kernel.org master: `include/uapi/linux/kfd_ioctl.h` defines
`KFD_IOCTL_MAJOR_VERSION 1`, `MINOR 23`, `AMDKFD_IOC_SVM`, `AMDKFD_IOC_SET_XNACK_MODE`,
`AMDKFD_IOC_CREATE_QUEUE`, `AMDKFD_IOC_ALLOC_MEMORY_OF_GPU`, `AMDKFD_IOC_MAP_MEMORY_TO_GPU`,
`AMDKFD_IOC_CREATE_EVENT`, `AMDKFD_IOC_WAIT_EVENTS`, `AMDKFD_IOC_ACQUIRE_VM`.

The pitch "the fastest inference stack for unified-memory machines, across vendors" stays out of every
README until a paired A/B receipt backs it on at least two vendors.

### 5. Second backend: AMD first, Vulkan as the broad fallback

**The AMD backend is `.om` end to end:** `/dev/kfd` + a DRM render node for the driver client, AQL
packets written by the backend, the direct gfx encoder of Decision 3, an HSACO writer. It does not link
ROCr or HIP. ROCr/HSA (`hsa_amd_svm_*`, AQL) is the reference for behaviour and a test oracle.

Required Omega extension (proposal to file before P3 code): widen omc's `devctl` allowlist, today
NVRM-only, with the exact KFD ioctl requests and payload sizes from `kfd_ioctl.h` 1.23, the same way
`uvmctl` lists UVM requests from the pinned 580.173.02 ABI.

**Vulkan** needs the Vulkan loader, a C shared library. omc cannot call shared libraries (fact 8), so a
`.om` Vulkan backend needs a second extension proposal: checked calls into ELF/Mach-O shared libraries.
Until it lands, `vk-host.c` (draft #876) stays the disclosed interim C launcher behind
`migration-pending`. Metal has the same prerequisite. Direct DRM ioctls (amdgpu, v3d, msm) avoid the
loader on Linux and are the `.om`-native route where a vendor documents its uAPI.

**Licences, checked 2026-10-27 from upstream files** (we use public interfaces and documentation; no
code is copied):

| Component | Licence | Source checked |
|---|---|---|
| Linux amdgpu driver | `MODULE_LICENSE("GPL and additional rights")` | `drivers/gpu/drm/amd/amdgpu/amdgpu_drv.c` |
| KFD uAPI header | MIT-style permission notice, AMD 2014 | `include/uapi/linux/kfd_ioctl.h` |
| ROCR-Runtime (HSA runtime) | University of Illinois/NCSA | ROCm/ROCR-Runtime `LICENSE.txt`; repo marked deprecated, moved to ROCm/rocm-systems `projects/rocr-runtime` |
| ROCT thunk (libhsakmt) | MIT | ROCm/ROCT-Thunk-Interface `LICENSE.md` |
| HIP runtime (CLR) | MIT | GitHub licence field, ROCm/clr |
| LLVM (AMDGPU backend; oracle only) | Apache-2.0 WITH LLVM-exception | llvm/llvm-project `llvm/LICENSE.TXT` |
| SPIR-V headers | MIT-style Khronos | KhronosGroup/SPIRV-Headers `LICENSE` |
| Vulkan headers | Apache-2.0 or MIT per file | KhronosGroup/Vulkan-Headers `LICENSE.md` |
| MoltenVK | Apache-2.0 | GitHub licence field |
| AMD ISA reference guides | AMD document terms, not yet read | **open: the IP-lawyer review Drake requires covers this** |

**Hardware we can reach (probed read-only 2026-10-27T01:44Z):**

| Machine | GPU | Use | Status |
|---|---|---|---|
| DGX Spark | GB10 (sm_121) | GB10 backend, the head-to-head | reachable; GPU per lock rules |
| macbook | Apple M2, 10 GPU cores, Metal 4 (Darwin 25.6.0) | Metal backend; MoltenVK | reachable over SSH |
| hub | Raspberry Pi 5, V3D, `/dev/dri/renderD128` | Vulkan on real hardware via Mesa v3dv | reachable; no Vulkan ICD installed |
| iMac | AMD Polaris 10 (1002:67df rev c5, gfx803) | AMD driver-client bring-up only (pre-CDNA ISA; ROCm support for gfx803 ended [INFERENCE]) | offline at probe (SSH timeout, ping 100% loss); boots the aienux firmware-hosted UEFI app, which keeps the name Allen (its Omega port is draft aienux#495), not a host OS with an AMD driver |
| GitHub `ubuntu-24.04-arm` | lavapipe, CPU | Vulkan and CPU-reference CI | available |
| Rented MI300X | gfx942, 192 GB HBM3, discrete | AMD backend qualification | not rented; Drake's gate |

No Strix Halo, MI300A or Snapdragon machine is reachable. Their rows in Decision 4 stay PROPOSED.

**MI300X cost.** PLAN.md budgets MODELED $18.51 through the renting lane. Public third-party listings
on 2026-10-26 (not re-verified, not a quote) ranged $2.39–$4.42 per GPU-hour. WolframLanguageEvaluator:
`{18.51/4.42, 18.51/2.39}` → `{4.19, 7.74}` hours. AMD Developer Cloud offers one
MI300X with $100 credit for 30 days through the AMD AI Developer Program form, at AMD's discretion; a
powered-off VM is still billed (FreeCompute survey 2026-10-26). Every hour of a rental is planned in
advance: host-side encoder and HSACO work is finished on lavapipe/CPU and the iMac first.

### 6. Integration: plug into the ecosystem (P4)

Per ARCH-0042 Decision 3 these are omega-bridge attachments in connected repos, each pinning CUDApp and
omega-bridge by sha. Each calls compiled Omega through omega-bridge native bindings (BRIDGE-1: C, C++,
Python, Rust, Zig and Go callers on Linux AArch64). Effort is in lane-weeks, [INFERENCE].

| Target | Interface (checked 2026-10-27) | Maps to | Effort |
|---|---|---|---|
| **ggml / llama.cpp** (aien-dev/ggml-omega, draft #1, CPU backend today) | `ggml-backend-impl.h` at the pinned llama.cpp `7aca0d2e`, `GGML_BACKEND_API_VERSION 3`: `ggml_backend_reg_i` (`get_device_count`, `get_device`, `get_proc_address`), `ggml_backend_device_i` (`get_memory`, `get_props`, `init_backend`, `get_buffer_type`, `buffer_from_host_ptr`, `supports_op`, `offload_op`, `event_new`), `ggml_backend_i` (`set_tensor_async`, `graph_compute`, `graph_plan_*`, `event_record`, `event_wait`), buffer and buffer-type tables; loaded with `GGML_BACKEND_PATH` | `buffer_from_host_ptr` → `ob_mem_import_host` (zero-copy GGUF); `graph_compute` → one `ob_graph_launch` per token; `supports_op` from IR v7 coverage | 2–3 weeks to a GPU backend passing `test-backend-ops` for the ops it claims; first and cheapest, gives like-for-like llama-bench |
| **vLLM** | out-of-tree platform plugin: entry-point group `vllm.platform_plugins` returning the qualified name of a `vllm.platforms` `Platform` subclass (checked in `vllm/plugins/__init__.py` and `vllm/platforms/__init__.py` on main); `vllm.general_plugins` for custom ops | worker, attention backend, paged KV on the memory planner | 6–10 weeks; the hard part is that vLLM's tensors are PyTorch tensors, so it needs a PyTorch device for Omega memory or a host-tensor bridge. Starts after ggml |
| **ONNX Runtime** | plugin execution-provider library (`RegisterExecutionProviderLibrary`; the library exports `CreateEpFactories` / `ReleaseEpFactory`; `OrtEpFactory` `GetSupportedDevices` / `CreateEp`; `OrtEp` `GetCapability` / `Compile`; `onnxruntime_ep_c_api.h` on main, `ORT_API_VERSION 32`) | `GetCapability` claims the subgraphs IR v7 covers; `Compile` lowers them to a graph | 3–5 weeks; out of tree, no ORT fork |

### 7. Human review

- CUDApp gets a proposed `CODEOWNERS` (inactive until reviewers exist) and `REVIEWING.md` (draft PR).
  Core paths: the backend ABI header, every `backend/*/` encoder and driver client, the code-object
  writers, the runtime API manifest, and `THIRD_PARTY.md`. checker2 and the IR lowering live in
  omega-mv (Decision 1), so CUDApp's CODEOWNERS cannot cover them; they are reviewed on omega-mv PRs.
- Merge rule: everything keeps PLAN.md's agent rule (CI green, gates re-run from a fresh clone on the
  exact head, receipts posted, a non-author approval, `--match-head-commit`, no self-merge). **Once
  human reviewers exist, a PR touching a core path also needs one approving human review.**
  Enforcement is a GitHub ruleset change, which is Drake's decision.
- Drake requires one IP-lawyer review and at least two experienced GPU or compiler engineers. He
  chooses the people. Invitation drafts are prepared for him, unsent, in
  `~/handoffs/SplitDesign/INVITATIONS.md`; no one is contacted by agents.

## Consequences

- In the `.om` stack two backend tables become one, and raw method words and the two bypasses have no
  place in it. The C stack is frozen, not reworked, and is retired kernel by kernel once the `.om`
  stack matches it on chip with identical golden tokens.
- The GB10 C backend stays as migration; new backends and the new top are `.om`. Three Omega extension
  proposals are prerequisites: (E1) the KFD `devctl` allowlist; (E2) checked shared-library calls
  (Vulkan loader, Metal) and Mach-O output for macOS; (E3) IR v7, filed as aien-dev/omega-mv#883.
- Encoding provenance becomes a backend gate. CUDApp `docs/HOW_I_DID_IT.md:35-39` says "Where nvcc and
  NAK disagree for sm_121, I follow what nvcc emits"; PLAN.md requires encodings re-derived from NAK
  plus chip tests, never from nvcc. The GB10 backend's encoder carries an inventory of every field with
  its NAK citation or chip test before it is declared the backend. Nothing derived from omega-mv #864
  enters any backend while it is on HOLD.
- Nothing here is implementation or qualification evidence. Every row above is PROPOSED.

## Source

- PLAN.md phases P2–P4 and Rules; the 2026-10-27 outside review.
- `~/handoffs/SplitDesign/filemap.md` (CUDApp `780a0af1`, file:line evidence).
- `~/handoffs/SplitDesign/c1path.md` (omega-mv `omegese/gpu-front` `d1ac019e`, C1 verbatim, IR v6).
- omega-mv main `e5b32567`: `seed/host/MAPPING.md`, `docs/one_layer/OMEGESE.md` §10–11.
