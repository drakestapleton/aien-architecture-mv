# PREFILL-3 Specification (branch-aware exact shared-prefix attention)

**Status:** PROPOSED. Written 2026-10-01. Docs only. Nothing in this file has been built or run on any tier (host, QEMU or GB10 hardware). Every gate below is NOT_RUN.
**Authority:** operator material of 2026-10-01 (Drake Stapleton), recorded in `~/handoffs/2026-10-01-prefill-program-pass2.md` (ladder step 3, "BRANCH-AWARE ATTENTION") and `~/handoffs/2026-10-01-prefill-artifact-idea.md`. Pasted operator material is pre-approved. Where this text and that material differ, the material wins and the difference is a defect in this text.
**Not a master plan and not a milestone.** `CURRENT_EXECUTION_PLAN.md` owns sequencing and `doctrine/ROADMAP.md` owns milestone status (`PLAN_AUTHORITY.md`). PREFILL-3 is one finite cut of the prefill program. It changes no model architecture.
**Layout copied from:** `docs/plans/prefill/PREFILL-0-SPEC.md` (aien-architecture PR #103, branch `hive/PREFILL-0-SPEC-prefill`, not yet merged).

Snapshots used for every fact below: aien-sovereign-core `cfd9982` (`cfd99827ca5483c08d549ca32c7ee3d3bde6f2d8`), read with `git show cfd9982:<path>` and `git grep ... cfd9982`; aien-architecture `origin/main` `7b8ca8a`. The scout report `~/handoffs/2026-10-01-PREFILL-SCOUT-scout.md` supplied the swarm and scheduler facts. All sovereign-core paths are relative to that repository and every line number is for `cfd9982`. Nothing was compiled or executed for this spec.

---

## In plain words (read this first)

When many AIEN agents branch from the same long document, each agent today re-reads the whole shared document from memory every time it writes one word. With 500 agents that is 500 separate reads of the same text, word after word. Hydragen (a 2024 research method) shows a way to read the shared part once for all agents together, read each agent's own private part separately, and then combine the two answers with a small exact correction so the result is the same as if each agent had read everything on its own. This spec says where that change would go in my GPU code, what math must hold for the shortcut to be exact, and which tests must pass before anyone may claim it works. Along the way, reading today's GPU code turned up three things that must be fixed or confirmed first (section 2.4).

---

## 1. Thesis

Shared-prefix attention is computed once per query batch across all branches that share the prefix (one matrix multiply over the shared prefix K/V for the stacked queries of every branch), suffix attention is computed per branch, and the two partial results are combined exactly with log-sum-exp rescaling. The decomposition generalizes from one shared prefix to a tree of shared segments. Exactness is a proof obligation (section 5) plus a measured numerical parity gate (section 7), never an assumption.

## 2. Current state at sovereign-core `cfd9982`

### 2.1 Where attention runs today

There are three native attention implementations. Only two are reachable from the production `NativeTransformerBackend::new_blackwell` path that the runtime daemon builds (`crates/aien-cli/src/commands.rs:1120`).

| # | Implementation | File:line | What it does today | Production reachable |
|---|---|---|---|---|
| A1 | GB10 cooperative paged decode attention (CUDA, comment says "Blackwell sm_121") | `crates/aien-inference-abi/cuda/paged_attention_bf16.cu:59-232` (kernel `paged_attention_bf16_cooperative_kernel`, signature `:62-75`), host entry `paged_attention_bf16_forward` `:264-385` | One query vector per sequence (decode only). Grid is `(ceil(num_q_heads / WARPS_PER_BLOCK), num_seqs)` (`:353-354`); one warp per query head (`:59-60, :80-81`); grouped-query mapping `kv_head = q_head / (num_q_heads / num_kv_heads)` (`:92-93`). Walks the sequence's own row of the block table (`:126-130`) over the canonical layout `[block][layer][K/V plane][token][kv_head][head_dim]` (`:61`). Softmax is single-pass online (flash-decoding style): `m_prev = -1e20f`, `l_prev = 0` (`:115-116`); per key `m_new = max(m_prev, s)`, `alpha = exp(m_prev - m_new)`, `beta = exp(s - m_new)`, `l_new = l_prev*alpha + beta`, accumulator rescaled by `alpha` and incremented by `beta*v` (`:193-212`); final normalize by `1/l` (`:217-231`). Running max and denominator live only in registers and are never written out. | Yes, for decode (path below) |
| A2 | Batched decode attention + ragged causal prefill attention inside the fused layer executor (CUDA) | `crates/aien-inference-abi/cuda/blackwell_layer.cu:267-370` (`batched_decode_attention_kernel`), `:372-455` (`ragged_prefill_attention_kernel`), launched at `:741-762` | Decode kernel: grid `(num_q_heads, decode_count)`, 64 threads (`:743-745`), three-pass softmax (scores into shared memory `:323`, max `:327-334`, exp-sum `:336-349`, weighted V `:351-368`). Prefill kernel: grid `(num_q_heads, prefill_count)`, 64 threads (`:754-756`); causal attention computed only over the rows of the current batch's `qkv` buffer (`:409-411, :449`); it does not read the paged KV pool. | No. `BlackwellBatchExecutor` is exported (`crates/aien-inference-abi/src/lib.rs:32`) and called from `blackwell_batch_executor.rs:584, :681`, but `git grep` over `crates/*/src/*.rs` at `cfd9982` finds no other user; its test is `crates/aien-inference-abi/tests/blackwell_batch_executor_parity.rs:93`. |
| A3 | CPU reference attention (Rust) | `crates/aien-inference-abi/src/backend.rs:147-214` (default `paged_attention`, online softmax `:193-202`), `:216-260` (default `paged_attention_batch`, sequential per sequence), `:342-390` (`gqa_attention`, two-pass f64 softmax `:376-384`) | Host reference and the GB10 fallback. | Yes |

**Production call path on GB10 (by reading, not executed).**

- Decode: `NativeTransformerBackend::forward_decode_batch` (`crates/aien-inference-abi/src/transformer_backend.rs:919`) gathers each request's own block table and context length (`:1065-1089`) and calls `tensor_backend.paged_attention_batch` (`:1091`). `BlackwellGb10Backend::paged_attention_batch` (`crates/aien-inference-abi/src/blackwell_backend.rs:396-466`) converts Q to BF16, sets `sm_scale = 1/sqrt(head_dim)` (`:421`), and calls `paged_attention_bf16` (`:428`) which calls the A1 host entry (`:191-236`). On failure it falls back to A3 (`:450-466`).
- Prefill: `prefill_prompt_layer_by_layer_paged` (`transformer_backend.rs:687`) applies RoPE at prompt-local position `t` (`:786`) and calls `backend.gqa_attention` per token (`:809`). `BlackwellGb10Backend::gqa_attention` forwards straight to the CPU fallback (`blackwell_backend.rs:339-359`). So on GB10 today, prefill attention runs on the CPU.

### 2.2 Answers to the brief's questions

| Question | Answer at `cfd9982` | Evidence |
|---|---|---|
| Does the kernel batch across sequences? | Yes, as independent grid rows. Each sequence (grid y) reads its own block table row and its own K/V; there is no reuse of a K/V block across sequences inside one launch. With N branches sharing one prefix of length P, the prefix K/V is read N times per layer per decode step. | `paged_attention_bf16.cu:81, :127, :353-354` |
| Paged KV? | Yes. Physical blocks via `block_tables[seq * max_blocks_per_seq + b]`, byte-stride addressing through `KvLayoutDesc` (C struct `paged_attention_bf16.cu:44-56`, Rust `#[repr(C)] KvLayoutDesc` `crates/aien-kv-cache/src/lib.rs:126-140`). Forked branches already point at the same physical prefix blocks (zero-copy fork, `crates/aien-kv-cache/src/lib.rs:963-985`, per scout). | as cited |
| How is softmax done? | A1 and A3 paged: single-pass online softmax with running max and denominator in registers (not exported). A2 and A3 `gqa_attention`: explicit max pass, exp-sum pass, weighted-V pass. | `paged_attention_bf16.cu:193-212`; `backend.rs:193-202, :376-384`; `blackwell_layer.cu:327-368` |
| Is a shared-prefix or multi-query (more than one query per sequence) paged kernel present? | No. A1 takes exactly one query vector per sequence (`q + (seq*num_q_heads + head)*head_dim`, `paged_attention_bf16.cu:95`). | as cited |
| Is there a native attention kernel at all? | Yes (A1, A2). A1 is the decode path; there is no native GPU prefill attention on the production path. | section 2.1 |

### 2.3 Other facts that shape the design

- **KV pool memory is host heap.** The default pool buffer is `HeapUnifiedBuffer` (`crates/aien-kv-cache/src/lib.rs:270`), allocated with `std::alloc::alloc_zeroed` (`:285-287`, used at `:586`). A1's host entry treats a pointer as device-usable only if CUDA reports it as device or managed (`paged_attention_bf16.cu:234-242`); otherwise it copies the whole pool host to device on every call (`:340-349`, copy at `:347`) and synchronizes the device after the launch (`:374`). `blackwell_allocate_managed` exists (`crates/aien-inference-abi/cuda/blackwell_gemm.cu:194-196`) but `git grep` finds no Rust caller beyond its declaration (`blackwell_backend.rs:49, :113`). Inference: every decode attention call on GB10 moves the full KV pool. UNVERIFIED by execution, confidence 80% (GB10 unified-memory pointer attributes for pageable heap memory not measured).
- **The scout's open follow-up stands.** Branches in the swarm path still decode from an empty per-sequence state (`transformer_backend.rs:939-948`), so they do not yet consume a shared root prefill. PR #145 (aien-sovereign-core, open) closes only the scheduling gate.

### 2.4 Defect candidates found while reading (not part of PREFILL-3 scope, must be resolved or ruled out first)

| # | Candidate | Evidence | Status |
|---|---|---|---|
| K1 | A2 kernels launch 64 threads (two warps) but reduce max and exp-sum only within a warp (`__shfl_down_sync` over offsets 16..1) and then take thread 0's value. Warp 1's partial max and partial sum are dropped, so the softmax denominator misses half of the keys. | `blackwell_layer.cu:327-334, :341-348` (decode), `:423-430, :437-443` (prefill), launches `:745, :756` | UNVERIFIED by execution, confidence 85%. Not production reachable (A2). |
| K2 | A2 shared memory for scores is fixed at 2048 floats ("up to 2048 tokens context in shared mem") with no bound check on `t` before `s_scores[t] = ...`. Context longer than 2048 writes past the allocation. | `blackwell_layer.cu:744, :755, :323, :419` | UNVERIFIED by execution, confidence 85%. Not production reachable. |
| K3 | A2 prefill attention reads keys only from the current batch rows, so a prefill chunk or an appended suffix cannot attend to earlier cached K/V. | `blackwell_layer.cu:409-411, :449` | Confirmed by reading. Matters for any suffix-over-prefix design. |
| K4 | Prefill RoPE uses prompt-local position `t` starting at 0. A suffix prefilled after a shared prefix must use absolute positions `P + t`. | `transformer_backend.rs:786` | Confirmed by reading for `prefill_prompt_layer_by_layer_paged`. |

K1 and K2 mean A2 must not be used as a parity baseline. K3 and K4 bound ladder step 2 (exact prefix reuse) and are prerequisites for PREFILL-3.

## 3. Files that would change (proposal)

| File:line at `cfd9982` | Change |
|---|---|
| `crates/aien-inference-abi/cuda/paged_attention_bf16.cu:59-232` | Keep the existing kernel as the per-branch baseline and suffix kernel. Add an option to write per (query, head) the running max `m` and denominator `l` (or `lse = m + ln l`) and the unnormalized or normalized partial output, instead of only the normalized output (`:217-232`). |
| `crates/aien-inference-abi/cuda/paged_attention_bf16.cu` (new kernels beside `:59`) | (a) Shared-prefix kernel: for one prefix group, stack the queries of all G branches (and all query heads mapped to one KV head under GQA, `:92-93`) into a `[G*heads_per_group, head_dim]` matrix and compute `S = Q K_prefix^T`, softmax statistics and `S V_prefix` as tiled matrix multiplies that read each prefix K/V block once per group. (b) Merge kernel: LSE combination of prefix and suffix partials (section 4.3). |
| `crates/aien-inference-abi/cuda/paged_attention_bf16.cu:264-385` | Host entry: accept device-resident or managed buffers without whole-pool copies (`:340-349`); accept the prefix-group descriptor (section 4.4). |
| `crates/aien-inference-abi/src/blackwell_backend.rs:31-47, :191-236, :396-460` | FFI declaration, safe wrapper and `TensorBackend::paged_attention_batch` override gain a prefix-group path; fallback stays A3. |
| `crates/aien-inference-abi/src/backend.rs:147-260` | Host CPU reference of the same decomposition (exact f64 two-part LSE merge) beside the existing reference; this is the host leg oracle. |
| `crates/aien-inference-abi/src/transformer_backend.rs:1065-1103` | `forward_decode_batch` groups decode requests by shared FrozenShared prefix artifact instead of passing N independent full block tables. |
| `crates/aien-kv-cache/src/lib.rs:126-140` | `KvLayoutDesc` is `#[repr(C)]` and ABI visible. PREFILL-3 should not change it; prefix-group metadata is a separate descriptor. Any change is called out in the PR. |
| `crates/aien-inference-abi/src/blackwell_batch_executor.rs:79-96` and `cuda/blackwell_layer.cu:83-99` (`BlackwellBatchPlanC`) | Not changed by PREFILL-3. A2 is not on the production path and has K1, K2. |

## 4. Design

### 4.1 Decomposition for one shared prefix

For a decode step, branch `i` (of `G` branches sharing a prefix of length `P`) has query `q_i` and keys `K = [K_pre ; K_suf_i]`, values `V = [V_pre ; V_suf_i]`, where `K_pre, V_pre` are the shared prefix blocks (physically one copy) and `K_suf_i, V_suf_i` are branch-local.

1. **Prefix part, once per group.** Stack `Q_pre = [q_1; ...; q_G]` (times the GQA query heads per KV head). Compute `S = scale * Q_pre K_pre^T` (a `[G*h, P]` matrix multiply), per row max `m_pre,i`, per row denominator `l_pre,i = sum_j exp(S_ij - m_pre,i)`, and `O_pre,i = (1/l_pre,i) sum_j exp(S_ij - m_pre,i) v_j`. The prefix K/V is read once for all G branches instead of G times.
2. **Suffix part, per branch.** The existing A1 kernel over the branch-local blocks only, extended to emit `m_suf,i`, `l_suf,i`, `O_suf,i`.
3. **Exact merge.** `M = max(m_pre, m_suf)`, `w_pre = l_pre exp(m_pre - M)`, `w_suf = l_suf exp(m_suf - M)`, `O = (w_pre O_pre + w_suf O_suf) / (w_pre + w_suf)`. Equivalently with `lse = m + ln l`: `O = (e^{lse_pre} O_pre + e^{lse_suf} O_suf) / (e^{lse_pre} + e^{lse_suf})`, evaluated in the max-subtracted form above.

Edge rules: an empty part has `l = 0` and `m = -inf` and contributes weight 0; the merge must not produce NaN when one part is empty (the current `-1e20f` sentinel at `paged_attention_bf16.cu:115` and the `l > 0` guard at `:218` are the starting point). Causality: during decode the whole prefix precedes every suffix token, so no mask is needed on the prefix part. For prefill of a branch suffix (ladder step 2), the suffix part is causal and the prefix part is unmasked.

### 4.2 Tree-shaped sharing

Sharing is a tree: each node holds a token segment shared by all branches below it (root = common document, inner nodes = shared sub-contexts such as a tool result common to a subset, leaves = branch-local tails). For a branch whose path is nodes `n_0 ... n_k`, attention is the LSE merge of `k+1` partials, one per node. Each node's partial is computed once for the stacked queries of every branch under that node. The merge is associative and commutative (section 5), so partials may be merged in any order or as a reduction tree. Two levels (one prefix, one suffix) is the first deliverable; arbitrary depth is the generalization.

### 4.3 Data emitted per partial

Per (branch, query head): `O` (head_dim, f32 during merge), `m` (f32), `l` (f32), or `O` and `lse`. Partials stay in f32 until the final merge; the final output is cast to the KV dtype once. No per-branch copy of prefix K/V is ever made (gate G4).

### 4.4 Prefix-group descriptor (proposal)

A new descriptor, separate from `KvLayoutDesc`, lists for each group: the prefix block list (one copy), prefix length `P`, the member branch indices, and per branch the suffix block list and suffix length. It is built from the scheduler's view of which branches share a FrozenShared PrefillArtifact (section 4.5), never inferred by comparing block ids on the fly.

### 4.5 Interaction with PrefillArtifact

- Only artifacts with `exactness_class = EXACT` (lineage-preserving shared prefix, pass-2 type-system rule) may be a shared node. COMPOSABLE or APPROXIMATE artifacts are never fed into the shared-prefix kernel; mixing is a hard error, not a fallback.
- Only artifacts in state `FrozenShared` (or `Ready`, frozen before the group is formed) may be shared. `Allocated` or `Computing` artifacts are refused (PREFILL-0 gates G1, G2).
- All binding fields must match across the group, in particular `model_digest`, `rope_config`, `absolute_position_range`, `kv_dtype`, `kv_layout`, `block_size`, `attention_layout` (pass-2 field list).
- **Depends on:** aien-sovereign-core PR #145 (prefill correctness, ladder step 1; open at time of writing) and ladder step 2 (exact prefix reuse: appended revision computes only the suffix, which needs K3 and K4 resolved). PREFILL-3 cannot produce a meaningful parity result before branches actually consume a computed shared prefix (section 2.3, scout follow-up).

## 5. Exactness proof obligation

**Obligation E1 (concatenation).** For a query `q`, keys `K = K_1 ++ K_2`, values `V = V_1 ++ V_2`, scores `s_j = scale * q . k_j`, define for part `p`: `m_p = max_{j in p} s_j`, `l_p = sum_{j in p} exp(s_j - m_p)`, `O_p = (1/l_p) sum_{j in p} exp(s_j - m_p) v_j`. Then with `M = max(m_1, m_2)`:

```
softmax(s) V over K_1 ++ K_2
  = sum_j exp(s_j - M) v_j / sum_j exp(s_j - M)
  = ( l_1 e^(m_1 - M) O_1 + l_2 e^(m_2 - M) O_2 ) / ( l_1 e^(m_1 - M) + l_2 e^(m_2 - M) )
```

Proof sketch to be written out in full in the implementation PR: split both sums over the two index sets and factor `exp(m_p - M)` out of each part. This matches the combination formula fetched from the Hydragen paper (section 9).

**Obligation E2 (associativity).** The merge operator on triples `(m, l, O)` is associative and commutative with identity `(-inf, 0, 0)`, so any tree of partials merges to the same exact value. Required for section 4.2.

**Obligation E3 (no overflow).** Every exponent evaluated is `<= 0` (always `x - M` with `M` the running or global max), so no `exp` overflows in f32.

**Obligation E4 (shared vs independent).** In exact arithmetic, shared-prefix attention for branch `i` equals independent attention for branch `i` over its full context. In floating point they differ only by summation order. Therefore exactness is judged by the tolerance rule below, not by bitwise equality.

**Numerical tolerance rule (no number is fixed in advance).** The tolerance is the measured noise floor of the existing per-branch path, defined as follows and recorded in the receipt:

1. Baseline-vs-baseline floor: run the per-branch baseline (A1 on GB10, A3 on host) on the same inputs under at least two summation orders that are mathematically equal (for example block order forward and reversed, or two split points of the online softmax), over the full case matrix of section 7. Record per element max absolute difference and max relative difference of attention outputs, and max absolute difference of final logits, per (context length, fanout, layer).
2. The noise floor for a cell is the maximum observed over those runs, reported with the run count.
3. Shared-vs-independent parity passes for a cell when the shared path's difference from the per-branch baseline does not exceed that cell's floor by more than the spread observed between repeated floor measurements; the exact pass rule (factor and run count) is fixed in the receipt before the shared path is run, never after.
4. An f64 host reference (A3 style) is the referee: both paths are also compared to it, and the shared path must not be further from f64 than the baseline is.

This is the PREFILL-0 G6 rule ("shared vs independently-prefilled agree within the measured numerical noise floor") applied to attention.

## 6. Out of scope

- Changes to the scheduler admission rule (PR #145).
- Exact prefix reuse across context revisions (ladder step 2), except as a dependency.
- Composable non-prefix reuse (ladder step 7).
- Fixing A2 (K1, K2): tracked as separate defect candidates.

## 7. Gates (all NOT_RUN)

| Gate | Definition |
|---|---|
| G1 parity | Shared-prefix attention output and final logits agree with the per-branch baseline (independent full-context attention per branch) within the measured noise floor of section 5, for every case in the matrix. Two-level and tree-shaped (depth at least 3) cases. Includes edge cases: empty suffix, suffix of one token, prefix not a multiple of `block_size`, GQA ratios used by the target models. |
| G2 mutants must fail | Each mutant is run through G1 and must FAIL: (M1) drop the rescale, merge as `(O_pre + O_suf)/2` or with `w = l` only; (M2) wrong max, use `m_pre` in place of `M` for the suffix weight; (M3) drop one part's denominator; (M4) read the suffix of a different branch. A mutant that passes G1 means G1 is too weak and G1 is void until strengthened. |
| G3 throughput | Decode attention throughput (tokens per second across all branches) and end-to-end decode throughput, shared path vs per-branch baseline, at fanouts 1, 8, 32, 128, 500 and contexts 32K, 128K and the backend's reported max context. Fanout 1 must show no material regression; the size of any regression is recorded, not assumed. |
| G4 memory | No per-branch copy of prefix K/V: physical KV bytes and bytes moved per decode step are measured; prefix K/V bytes read per step per group are independent of fanout (within a constant for tiling). No whole-pool host-to-device copy per call (section 2.3). |

## 8. Results

Every leg is NOT_RUN. QEMU: N/A (runtime kernel work, no guest boot).

| Gate | Host CPU reference (A3 decomposition vs A3 baseline, f64 referee) | GB10 hardware (new kernels vs A1 baseline) |
|---|---|---|
| G1 parity, two-level | NOT_RUN | NOT_RUN |
| G1 parity, tree depth >= 3 | NOT_RUN | NOT_RUN |
| Noise floor measured (section 5) | NOT_RUN | NOT_RUN |
| G2 mutant M1 fails | NOT_RUN | NOT_RUN |
| G2 mutant M2 fails | NOT_RUN | NOT_RUN |
| G2 mutant M3 fails | NOT_RUN | NOT_RUN |
| G2 mutant M4 fails | NOT_RUN | NOT_RUN |
| G3 throughput, fanout 1/8/32/128/500 x 32K | NOT_RUN | NOT_RUN |
| G3 throughput, fanout 1/8/32/128/500 x 128K | NOT_RUN | NOT_RUN |
| G3 throughput, fanout 1/8/32/128/500 x max | NOT_RUN | NOT_RUN |
| G4 memory, no per-branch prefix copy | NOT_RUN | NOT_RUN |
| G4 memory, no whole-pool copy per call | N/A (no device) | NOT_RUN |

Receipt shape: sovereign-core commit, backend, model digest, KV dtype, block size, GQA ratio, context length, fanout, the backend's reported max context, the noise floor and its run count, the pass rule fixed before the shared run, raw measurement files. Failing receipts are kept. GB10 chip runs go through the shared test queue and are never killed or timed out.

## 9. Outside references

- **Hydragen (VERIFIED, fetched 2026-10-01 from https://arxiv.org/abs/2402.05099 and https://arxiv.org/html/2402.05099v2).** Juravsky, Brown, Ehrlich, Fu, Re, Mirhoseini, "Hydragen: High-Throughput LLM Inference with Shared Prefixes", arXiv 2402.05099 (v2 revised 13 May 2024; ICML 2024 per https://icml.cc/virtual/2024/39631, listed in search results, page not fetched). Abstract: "Hydragen computes attention over the shared prefix and unique suffixes separately. This decomposition enables efficient prefix attention by batching queries together across sequences". Abstract: "Our method can improve end-to-end CodeLlama-13b throughput by up to 32x against competitive baselines". So "up to 32x" appears, as end-to-end CodeLlama-13b throughput. Hardware sentence from the paper body: "We distribute the model with tensor parallelism across eight A100-40GB GPUs in order to have enough GPU memory to store the KV cache with large batch sizes." Combination formula from the body: "SDP(Q,K,V) = [SDP(Q,K1,V1)e^LSE(Q,K1) + SDP(Q,K2,V2)e^LSE(Q,K2)] / [e^LSE(Q,K1) + e^LSE(Q,K2)]". Tree sharing, from the body (ellipsis inserted by the fetch tool): "the overlap between sequences forming a tree structure where each node contains a token sequence that is shared by all descendants". The fetch tool also summarized the 32x setting as batch size 1024, prefix 2048 tokens, 128 generated tokens, baseline vLLM 0.2.7 PagedAttention: UNVERIFIED as a quotation (summarizer output, not verbatim), confidence 70%; recheck before quoting. My hardware is one GB10, not eight A100s; the 32x figure is not a target or expectation for AIEN.

## 10. PARKED

- Model-level YOCO / DeepSeek CED: AIEN-native model lane, parked until an AIEN-native model is trained.
