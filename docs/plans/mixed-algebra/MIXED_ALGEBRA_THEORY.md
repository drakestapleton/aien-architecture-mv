# Mixed-Algebra Theory (Omega Mixed-Algebra Program)

Status: theory lane, draft for review. Scope: definitions, derivations, truth tables, win/lose conditions and test vectors for the hypotheses H1 to H7. No implementation claims.

Evidence legend used throughout:

- **[ENUM]** verified by exhaustive enumeration in a C program (`theory/check.c`, `theory/dr.c`, job scratch dir).
- **[MC]** checked by Monte Carlo simulation (4,000,000 samples per point).
- **[PROOF]** derived in this document.
- **[GROK]** independently checked by Grok (see Appendix A for agreement record).
- **CONJECTURE** not proven; must not be relied on without a gate.
- **PARAM** an example parameter, not a measured property of my hardware.

Notation: `T` denotes the balanced-ternary digit -1. Digit strings are written most significant digit first. `Q(x) = P(Z > x)` for standard normal `Z`. `u` is unit roundoff of a float format.

---

## 1. Algebraic domains

### 1.1 Definition

An **algebraic domain** is a tuple `D = (S, Ops, Ids, Cx)`:

- `S`: the carrier set (the values that exist in the domain).
- `Ops`: a finite set of named operations `f : S^k -> S` (or `S^k -> S x Flag` where a flag reports overflow, invalid input, or inexactness).
- `Ids`: the identities the operations are **guaranteed** to satisfy on all of `S` (for example associativity of `+`, distributivity, `x + 0 = x`). An identity not in `Ids` must not be used by any rewrite.
- `Cx`: the exactness/error contract. For every op either (a) EXACT: the result equals the mathematical result, or a flag is raised; or (b) BOUNDED: the result differs from a named reference function by at most a stated bound, with the rounding rule stated; or (c) WRAPPING: the result equals the reference modulo a stated modulus.

Two domains are **the same semantic domain** only if carrier, operations, identities and contract all agree. Same bits with a different contract is a different domain.

### 1.2 Semantic value domain vs realization encoding

- A **semantic value domain** says what the values and operations mean (for example "integers in [-2^31, 2^31) with trapping overflow").
- A **realization encoding** is a map `enc : S -> B` into machine states `B` (bit patterns, lanes, planes, phases) with decoding `dec : B_valid -> S`, `dec(enc(s)) = s`, plus machine operations `g` on `B`.
- A realization **implements** op `f` exactly on input set `I` iff for all `s in I`: `dec(g(enc(s))) = f(s)`.
- `B_valid` may be a strict subset of `B`. States in `B \ B_valid` (for example the bitplane state (1,1) of Section 3) must have a declared policy.

Balanced ternary digit strings, two bitplanes, a packed byte (5 trits per byte), a Z3 residue and a phase are all realization encodings. Integers, Z3 and floats are semantic domains. The same encoding can serve different semantic domains (Section 5: the same trit planes realize integer addition with carry, or Z3 addition without carry).

### 1.3 Catalogue

| Domain | Carrier | `+` assoc/comm | `*` assoc/comm | distributive | Contract |
|---|---|---|---|---|---|
| Z | all integers | yes/yes | yes/yes | yes | EXACT, unbounded storage |
| Bounded int `[L,U]` | integers in range | only where no overflow | only where no overflow | only where no overflow | EXACT + overflow flag, or WRAPPING (then it is Z_m, below) |
| Balanced ternary, n trits | integers in `[-(3^n-1)/2, (3^n-1)/2]` | as bounded int | as bounded int | as bounded int | EXACT + overflow flag |
| Z3 | {0,1,2} | yes/yes | yes/yes | yes | WRAPPING mod 3 (it is a field, GF(3)) |
| Z_m, RNS | Z_M via CRT | yes/yes | yes/yes | yes | WRAPPING mod M |
| IEEE binary32/64, BF16, FP8, NVFP4 | finite floats, inf, NaN | comm yes, **assoc no** | comm yes, **assoc no** | **no** | BOUNDED per op: `fl(a op b) = (a op b)(1+d)`, `|d| <= u` (absent overflow/underflow) |
| Phase domain mu3 | {1, w, w^2}, `w = e^{2 pi i/3}` | n/a | group op = complex mult, assoc/comm | n/a | EXACT in the ideal; realized with noise (Section 6) |

Wrapping bounded integers (two's complement with wrap) are the ring Z_{2^k}; this is a legitimate domain, but it is a different semantic domain from trapping bounded integers.

### 1.4 Float non-associativity (counterexamples) [ENUM]

All computed with round-to-nearest-even at the stated significand width (hidden bit included in the width):

| Format | Left grouping | Right grouping |
|---|---|---|
| binary64 | `(1e20 + -1e20) + 1 = 1` | `1e20 + (-1e20 + 1) = 0` |
| binary32 | `(1 + 2^-24) + 2^-24 = 1` | `1 + (2^-24 + 2^-24) = 1 + 2^-23` |
| BF16 (8-bit significand) | `(256 + 1) + 1 = 256` | `256 + (1 + 1) = 258` |
| FP8 E4M3 (4-bit significand) | `(16 + 1) + 1 = 16` | `16 + (1 + 1) = 18` |
| FP4 E2M1 element (2-bit significand), as in NVFP4 | `(4 + 1) + 1 = 4` | `4 + (1 + 1) = 6` |

Consequences for the contract: a float reduction `sum_i x_i` is not a single function of the multiset `{x_i}`; it is a function of the reduction tree. A float realization is only "the same" as another if the reduction order is part of the contract, or if both are compared against a common bound. The standard forward bound for recursive summation is `|fl(sum) - sum| <= gamma_{n-1} * sum |x_i|` with `gamma_k = k u / (1 - k u)` (Higham 2002, "Accuracy and Stability of Numerical Algorithms").

NVFP4 note: NVFP4 is a block format (E2M1 elements with a shared per-block scale; NVIDIA describes blocks of 16 with an FP8 E4M3 scale plus a per-tensor FP32 scale; prior art to verify against the current NVIDIA spec). The element grid is `{0, 0.5, 1, 1.5, 2, 3, 4, 6}` with sign. Its semantics are therefore "scaled grid value", and any mixed-algebra rewrite must carry the scale as part of the value.

---

## 2. Balanced ternary (H1)

### 2.1 Definition

Digits `d_i in {-1, 0, +1}`. An n-trit string denotes `v = sum_{i=0}^{n-1} d_i 3^i`. The **canonical form** of an integer is its shortest string (no leading zero digit; zero is the single digit `0`).

### 2.2 Range and uniqueness [PROOF, ENUM n = 1..10]

Claim: the map from n-trit strings to integers is a bijection onto `R_n = [-(3^n - 1)/2, (3^n - 1)/2]`.

Proof sketch. `|v| <= sum 3^i = (3^n - 1)/2`, so the image lies in `R_n`. `|R_n| = 3^n` equals the number of strings, so it suffices to show injectivity. Suppose two strings `d != e` have the same value; let `j` be the lowest index with `d_j != e_j`. Then `sum_{i>=j} (d_i - e_i) 3^i = 0`, divide by `3^j`: `(d_j - e_j) + 3 * (...) = 0`, so `d_j - e_j` is divisible by 3. But `d_j - e_j in {-2, -1, 1, 2}`. Contradiction. Existence for every integer follows from the digit extraction algorithm: `r = x mod 3 in {0,1,2}`; set `d = r` if `r < 2` else `d = -1`; recurse on `(x - d)/3`, which has strictly smaller magnitude for `|x| >= 2`.

Enumeration confirmed bijectivity for every n from 1 to 10, and round-trip `x -> bt -> x` for every `x` in `[-200000, 200000]`.

### 2.3 Negation is digit flip [PROOF, ENUM]

`-v = sum (-d_i) 3^i` and `-d_i` is a legal digit, so flipping every digit gives a representation of `-v`; by uniqueness it is the canonical one. No carry, no increment (contrast two's complement: `-x = ~x + 1`, which carries). Verified for all `x in [-200000, 200000]`.

### 2.4 Rounding equals truncation [PROOF, ENUM]

Precise statement. Let `x` be an integer with canonical digits `d_i`, and `k >= 1`. Let `q = sum_{i>=k} d_i 3^{i-k}` (delete the k lowest trits). Then:

1. `|x - q 3^k| <= (3^k - 1)/2 < 3^k / 2`, so `q` is **the unique nearest integer** to `x / 3^k`.
2. No ties occur, because `x / 3^k` can never be a half-integer (`3^k` is odd).
3. Composition: `trunc_j(trunc_k(x)) = trunc_{j+k}(x)` trivially, hence `round(round(x/3)/3) = round(x/9)` for all integers `x`. Double rounding is harmless.

Proof of (1): the deleted tail is `sum_{i<k} d_i 3^i`, bounded by `sum_{i<k} 3^i = (3^k - 1)/2`.

Enumeration: (1) and (2) for all `x in [-100000, 100000]` and `k in 1..6`; (3) for the same range.

Contrast (binary) [ENUM]: double rounding with round-half-even is not composable. Counterexample: `x = 11`. `round_even(11/4) = 3`, then `round_even(3/2) = 2`; but `round_even(11/8) = 1`.

Limits and counterexamples to over-generalizing the property:

- It is rounding to nearest **multiple of `3^k`**. It says nothing about dividing by 2, 10, or any non-power-of-3 scale; a quantization scale `alpha` that is not `3^k` loses the property.
- Fractions with infinite expansions do have ties: `1/2 = 0.1111..._bal3 = 1.TTTT..._bal3`. Truncating the first gives 0, the second gives 1. The property holds for finite digit strings only.
- It requires canonical digits in `{-1,0,1}`. A redundant (carry-save style) digit set such as `{-2..2}` breaks it: the string `(2)(2)` in positions (1,0) denotes 8; deleting the low digit gives 2, but `round(8/3) = 3`.
- It is not saturation: truncating a value that later overflows its width still needs an overflow flag.

### 2.5 Carry propagation in addition [PROOF, ENUM]

Full adder: inputs `a, b, c_in in {-1,0,1}`, `s = a + b + c_in in [-3, 3]`. Write `c_out = round(s/3) in {-1, 0, 1}` and digit `d = s - 3 c_out in {-1, 0, 1}` (verified over all 27 input triples). So the carry never leaves `{-1, 0, 1}`.

Two-operand, n-trit addition:

- Worst-case carry chain length is n (same as binary). Example: `111 + 001`: every position produces sum 2 = digit T, carry 1; result `1TTT` = 14. Exhaustive search over all `729 x 729` pairs of 6-trit operands confirms maximum chain length 6 [ENUM].
- Carry generation probability at a position with zero carry in (uniform independent digits): `|a + b| = 2` in 2 of 9 cases = 2/9.
- Carry continuation given nonzero carry in [ENUM]: with `c_in = 1`, carry out is 1 iff `a + b >= 1`: 3 of 9 cases = 1/3 (carry out cannot flip sign). Binary equivalent `P(c_out = 1 | c_in = 1) = 3/4`. Of these, the cases where the carry out exists **only because** of the carry in (pure propagation, `a + b = 1`) are 2/9 in ternary vs 2/4 (`a xor b`) in binary; the rest are fresh generation.
- CONJECTURE (standard run-length argument, not proven here): the expected longest pure-propagation chain for uniform random operands grows as `log_{9/2} n + O(1)` for balanced ternary, versus `log_2 n + O(1)` for binary. This affects only asynchronous or variable-latency adders; a synchronous adder is sized for the worst case n.

### 2.6 Radix economy (with caveat) [ENUM]

Cost model: representing numbers up to `N` in radix `b` needs `ceil(log_b N)` digits; if a digit's hardware cost is proportional to `b`, total cost `E(b, N) = b log_b N = (b / ln b) ln N`.

- `2 / ln 2 = 2.885390`, `3 / ln 3 = 2.730718`, `e = 2.718282`.
- Ratio `(3/ln3)/(2/ln2) = 0.946395`: ternary is about 5.4 percent cheaper under this model.

Caveat, stated plainly: this is a cost model about **digit hardware whose cost scales linearly with radix**. It does not apply to binary CMOS, where a stored trit costs two bits (bitplanes) or `log2 3 = 1.584963` bits at best (packed), and where a ternary operation is realized with binary gates. On my silicon the relevant quantities are bits moved and gates switched, covered in Sections 3 and 4. Radix economy is not an argument for ternary on the Spark.

Storage density: `log2 3 = 1.584963` bits per trit. Packing 5 trits per byte (`3^5 = 243 <= 256`) uses 1.6 bits per trit, efficiency `5 log2 3 / 8 = 0.990602`.

---

## 3. Bitplane encoding

### 3.1 Definition

A trit `t` is encoded as two bits `(P, N)`:

| t | P | N |
|---|---|---|
| 0 | 0 | 0 |
| +1 | 1 | 0 |
| -1 | 0 | 1 |
| (invalid) | 1 | 1 |

`value = P - N`. A vector of 64 trits is two 64-bit words `(P, N)`. Canonical iff `P & N == 0`.

### 3.2 Negation

`neg(P, N) = (N, P)`. Zero gates. Exact on canonical inputs, and maps `(1,1)` to itself.

### 3.3 Multiplication (H2) [PROOF, ENUM all 16]

`zP = (xP & yP) | (xN & yN)`
`zN = (xP & yN) | (xN & yP)`

Proof. For canonical inputs the product is +1 iff both are nonzero with the same sign (the two terms of `zP`), -1 iff both nonzero with opposite sign (the terms of `zN`), 0 otherwise. On canonical inputs at most one of the four AND terms is 1, so `zP & zN = 0` and the output is canonical.

Stronger fact: the value is bilinear in the bits:
`(xP - xN)(yP - yN) = xP yP + xN yN - xP yN - xN yP`.
Enumeration over all 16 input pairs, including `(1,1)`, confirms `val(zP, zN) = val(x) * val(y)` when `(1,1)` is read as value `P - N = 0`.

| x \ y | 0 (0,0) | +1 (1,0) | -1 (0,1) |
|---|---|---|---|
| 0 | 0 | 0 | 0 |
| +1 | 0 | +1 | -1 |
| -1 | 0 | -1 | +1 |

### 3.4 Addition [PROOF, ENUM]

Half adder `a + b = s + 3c`, all digits in `{-1,0,1}`:

| a \ b | -1 | 0 | +1 |
|---|---|---|---|
| -1 | s=+1, c=-1 | s=-1, c=0 | s=0, c=0 |
| 0 | s=-1, c=0 | s=0, c=0 | s=+1, c=0 |
| +1 | s=0, c=0 | s=+1, c=0 | s=-1, c=+1 |

Plane formulas (canonical inputs):

- `cP = aP & bP`, `cN = aN & bN`.
- `sP = ((aP ^ bP) & ~(aN | bN)) | (aN & bN)`
- `sN = ((aN ^ bN) & ~(aP | bP)) | (aP & bP)`

Derivation: `s = +1` exactly when `a + b = 1` (one operand +1, the other 0: `aP ^ bP` with neither negative) or `a + b = -2` (`aN & bN`). `s = -1` is the mirror image. Verified on all 9 canonical pairs, including canonical outputs.

Full adder from two half adders [ENUM all 27]: `(s1, c1) = HA(a, b)`, `(s2, c2) = HA(s1, c_in)`, `c_out = s-digit of HA(c1, c2)`. Enumeration shows `c1` and `c2` are never both nonzero with the same sign, so `HA(c1, c2)` never produces a carry, and `s2 + 3 c_out = a + b + c_in` in all 27 cases.

### 3.5 Min, max, consensus [ENUM]

With order `-1 < 0 < +1`:

- `max`: `P = xP | yP`, `N = xN & yN`
- `min`: `P = xP & yP`, `N = xN | yN`
- consensus (`x` if `x == y`, else 0): `P = xP & yP`, `N = xN & yN`

These are the Kleene strong-logic `OR`/`AND` when `+1 = true`, `-1 = false`, `0 = unknown`.

### 3.6 The fourth state (1,1)

Candidates and what each breaks (all breakages verified by enumeration):

| Reading of (1,1) | Consistent with | Breaks |
|---|---|---|
| **Redundant zero** (value `P - N = 0`) | mul (value-consistent on all 16 pairs), bilinear dot identity, even the OR-form dot (0 mismatches in 200,000 random 64-lane words containing (1,1) lanes) | canonicality (bit equality no longer equals value equality); zero test `~(P | N)`; nonzero count `popcount(P | N)`; half adder: `(1,1) + (+1)` gives `s = -1, c = +1` (value 2, true value 1), `(1,1) + (-1)` gives `s = +1, c = -1` (value -2, true value -1); max/min; packing to 5-trits/byte (no code exists) |
| **Poison / NaN-like** | mul propagates it for nonzero partners: `(1,1) * (+1) = (1,1)` | `(1,1) * 0 = (0,0)`: poison is silently erased by zero (IEEE gives `NaN * 0 = NaN`); in any popcount dot a poison lane contributes 0, so the result carries no trace of it; adder produces wrong canonical digits (above) rather than poison |
| **Contradiction / Belnap "both"** | if `(P, N)` is read as (evidence for, evidence against), `(0,0)` becomes "no information", `(1,1)` "both", and Belnap's four-valued logic (Belnap 1977, "A useful four-valued logic") has natural plane formulas | this changes the meaning of `(0,0)` from arithmetic zero to "unknown", so it is a different semantic domain, incompatible with every arithmetic formula above |
| **Unknown** | nothing extra: Kleene's third value is already the digit 0 in Section 3.5 | duplicates an existing state |
| **Forbidden** (validation fault) | every formula in this section, bit equality = value equality, `3^n` states per n lanes, packing | costs one check: `any(P & N) != 0` per word (one AND, one test) at trust boundaries |

Recommendation: keep **FORBIDDEN** as the arithmetic default. Reasons: (a) the redundant-zero reading silently corrupts addition, which is the most common op after mul; (b) the poison reading does not survive multiplication by zero or popcount reduction, so it would promise detection it cannot deliver; (c) Belnap semantics is useful but is a separate semantic domain and must carry its own domain tag, never share an arithmetic tag. Validation should run where data enters the domain (load, unpack, external input), not inside inner loops: mul, neg and the popcount dot never create `(1,1)` from canonical inputs (proved in 3.3), and the adder formulas never create it either (verified).

---

## 4. Multiplication avoidance (H3)

### 4.1 Identity and op counts

For `w_i in {-1, 0, 1}`:

`sum_i w_i x_i = sum_{i : w_i = +1} x_i - sum_{i : w_i = -1} x_i`

Op counts for an n-long dot with `z` zeros in `w`:

| Realization | multiplies | adds/subs | other |
|---|---|---|---|
| dense int8 MAC | n | n | none |
| ternary masked add | 0 | n - z | select/mask per lane (SIMD: 2 masked adds per lane-group) |
| index-list sparse | 0 | n - z | index loads (gather) |
| trit x trit bitplanes, 64 lanes/word | 0 | 1 sub per word | 4 AND, 2 OR, 2 popcount per word |

Ternary x ternary dot [PROOF, ENUM 200,000 random words]:
`dot = popc(xP&yP) + popc(xN&yN) - popc(xP&yN) - popc(xN&yP)`
and because the four AND terms are disjoint per lane on canonical data, the cheaper OR form is equal:
`dot = popc((xP&yP) | (xN&yN)) - popc((xP&yN) | (xN&yP))`.

### 4.2 Exact accumulator range [PROOF, ENUM]

With `x_i in [-128, 127]` and `w_i in {-1,0,1}`, each term lies in `[-128, 128]` (`-1 * -128 = +128`). The sum lies in `[-128 n, 128 n]`.

- int32 never overflows iff `128 n <= 2^31 - 1`, i.e. **n <= 16,777,215** (`2^24 - 1`). At `n = 2^24` the all-`(-1, -128)` input gives exactly `2^31`, one past `INT32_MAX`.
- If inputs are restricted to symmetric `[-127, 127]`: `n <= 16,909,320`.
- int16 accumulator: `n <= 255` (with -128 allowed), `n <= 258` (symmetric). This matters for kernels that use 16-bit partial sums; they must flush to 32 bits at least every 255 terms.

All LLM-scale hidden dimensions (thousands to tens of thousands) are far inside the int32 bound, so the int32 result is exact.

### 4.3 When ternary should win: roofline model

Parameters (per matrix-vector product, `M` rows, `n` columns, one input vector):

- `B` memory bandwidth (bytes/s), `C_r` sustained weight-ops/s for realization `r` (includes decode cost).
- `beta_r` bytes per weight: int8 1.0; 2-bit ternary 0.25; base-3 packed 0.2 (exactly `ceil(n/5)/n` per row); sparse index list `rho * b_idx / 8` where `rho` is the nonzero fraction and `b_idx` index bits.
- Time `t_r = max(beta_r M n / B, M n / C_r)`.

Win condition of r over int8 (both memory-bound): ratio `beta_int8 / beta_r`: 4x for 2-bit, 5x for base-3. The ceiling is reached only if `C_r >= B / beta_r`, i.e. 2-bit decode+accumulate must sustain `4B` weights/s and base-3 must sustain `5B` weights/s; int8 only needs `B` MAC/s.

Worked example, PARAM `B = 273 GB/s` (a figure to verify for the target machine), `n = M = 4096`:

| Realization | bytes | memory time | compute rate needed to stay memory-bound |
|---|---|---|---|
| int8 | 16,777,216 | 61.46 us | 2.73e11 MAC/s |
| 2-bit ternary | 4,194,304 | 15.36 us | 1.09e12 weight-ops/s |
| base-3, 5 trits/byte | 3,358,720 | 12.30 us | 1.36e12 weight-ops/s |

At `n = M = 8192` all times scale by 4 and the required rates are unchanged (rate depends only on `B / beta`).

Predictions (to be gated, not claims):

1. PREDICTION: at batch 1, from DRAM, 2-bit ternary beats int8 GEMV by up to 4x if and only if the decode path sustains more than `4B` weight-ops/s; otherwise it is compute-bound and the speedup is `C_2bit / B`.
2. PREDICTION: base-3 packing beats 2-bit by at most 1.25x, and only if base-3 decode (a 243-entry table lookup or multiply-shift sequence per byte) sustains `5B`. If decode is the bottleneck, 2-bit wins because its decode is shifts and masks.
3. PREDICTION: when weights are cache-resident (effective `B` very large) or batch `b` is large (weight bytes amortized over `b` vectors), the problem is compute-bound. Then the fast path for ternary on a CPU with int8 dot-product instructions (sdot, i8mm) is **decode trits once into int8 `{-1,0,1}` tiles and use the int8 instructions**. Multiplication avoidance itself gives no speed on such a CPU, because the hardware multiply-accumulate is not slower than an add. It saves energy and area only on hardware where multipliers are a real cost (custom logic, analog), not on the Spark CPU.
4. Crossover batch size: int8 becomes compute-bound at `b* = C_int8 / B` (MACs per byte); ternary at `b*_r = C_r beta_r / B`. Above both, the ranking follows `C` alone.

### 4.4 Sparse index-list break-even

Storing indices of nonzeros (separate `+` and `-` lists so the sign is free), bytes per weight `rho b_idx / 8`, ignoring per-row headers:

- vs int8: `rho < 8 / b_idx` (16-bit indices: always wins below 50 percent density).
- vs 2-bit: `rho < 2 / b_idx`: 16-bit indices need `rho < 12.5%`; 8-bit block-local indices (blocks of 256 columns) need `rho < 25%` plus block headers.
- vs base-3: `rho < 1.6 / b_idx`: 16-bit indices need `rho < 10%`.
- Lower bound on any encoding: entropy `H(rho) = h(rho) + rho` bits per weight with `P(0) = 1 - rho`, `P(+1) = P(-1) = rho/2` [ENUM]: 0.569 bits at `rho = 0.1`, 1.061 at 0.25, 1.500 at 0.5, 1.585 (= `log2 3`) at `rho = 2/3`.
- Compute side: index lists turn streaming loads of `x` into gathers. For GEMV `x` is `n` bytes and typically cache-resident, so gathers hit cache; for large `n` or batch they do not. CONJECTURE: the sparse realization is only worth gating below about 10 percent density on this CPU.

Measured density of real ternary models is prior art to verify (for example Ma et al. 2024, "The Era of 1-bit LLMs: All Large Language Models are in 1.58 Bits", reports ternary weights; the zero fraction must be measured on my own checkpoints).

---

## 5. Z3 (H4)

### 5.1 The bijection and what it preserves [PROOF, ENUM]

`phi : {0, 1, 2} -> {0, 1, -1}`, `phi(0) = 0`, `phi(1) = 1`, `phi(2) = -1`.

- Multiplication: for all 9 pairs `phi(a b mod 3) = phi(a) * phi(b)` computed in Z [ENUM]. So `phi` is an **isomorphism of multiplicative monoids** `(Z3, *) ~ ({-1,0,1}, *)`, and `{-1,0,1}` is closed under integer multiplication. Ternary weight multiplication means the same thing in both worlds.
- Addition: `phi` is **not** additive into bounded signed integers. Counterexample: `1 + 1 = 2 = -1` in Z3, but `1 + 1 = 2` in Z (out of the one-trit range; a saturating trit gives 1). Likewise `2 + 2 = 1` in Z3, but `(-1) + (-1) = -2` in Z. These are the only two disagreeing pairs out of 9 [ENUM].
- `phi` is a ring isomorphism from Z3 onto `{-1,0,1}` with arithmetic **mod 3** (balanced residues). That ring is not the bounded integers.

Where they agree: any integer computation `F` built from `+`, `-`, `*` satisfies `F(x) mod 3 = F_Z3(x mod 3)`. So integer arithmetic followed by reduction mod 3 is an exact realization of a Z3 computation (provided the integer part does not overflow). The converse is false: a Z3 result does not determine the integer result.

### 5.2 Carry-free property

Z3 addition on vectors is lane-independent: no information crosses lanes or digit positions. On bitplanes, Z3 addition is exactly the half-adder sum digit `s` of Section 3.4 with the carry discarded, because `s = a + b - 3c == a + b (mod 3)` [ENUM, all 9 pairs]. Z3 multiplication is the H2 mul formula unchanged.

### 5.3 Which workloads are Z3 and which are integer

Genuinely Z3 (result is defined mod 3, wrap is correct):

- linear codes over GF(3), for example the ternary Golay code (Golay 1949, "Notes on digital coding"); syndrome computation is a GF(3) matrix-vector product.
- checksums and hashes defined mod 3 (parity-like invariants), ternary LFSR sequences.
- GF(3) polynomial arithmetic and convolution (Section 8.4, op 6).

Integer, not Z3 (wrap is a bug):

- neural network dot products and accumulations (the sum 2 must stay 2).
- counting, histograms, thresholds, comparisons, argmax.
- anything followed by an order comparison: Z3 has no order compatible with addition.

Classifier rule: if the program ever compares, thresholds, or rescales the result, it is integer. If it only ever adds, multiplies and tests equality with results defined mod 3, it may be Z3.

---

## 6. Roots of unity (H5)

### 6.1 Isomorphism [PROOF]

`psi : Z3 -> mu3`, `psi(a) = w^a`, `w = e^{2 pi i / 3}`. Then `psi(a + b) = w^{a+b} = psi(a) psi(b)`, `psi(0) = 1`, and `psi` is a bijection, so `(Z3, +) ~ (mu3, *)` as groups. Negation maps to complex conjugation: `psi(-a) = conj(psi(a))`.

### 6.2 Physical realization of addition

Z3 addition is **phase addition**: cascading two phase shifts of `2 pi a / 3` and `2 pi b / 3` gives `2 pi (a+b)/3` modulo `2 pi`, with the wrap done for free by the circle. Candidate physical mechanisms: cascaded phase shifters or delay lines on a carrier; a mixer (multiplying two sinusoids produces the sum-frequency term whose phase is the sum of phases, after filtering). Wrap-around (the carry of integer addition) does not exist, which is exactly Z3's carry-free property.

### 6.3 Decision regions and error probability

Detector: for received `r`, decide `k` maximizing `Re(r conj(w^k))`. For equal-energy symbols this is the ML detector under circular Gaussian noise, and the regions are three 120-degree sectors centered on the symbols (boundaries at +-60 degrees from each symbol).

**Additive white Gaussian noise.** Unit amplitude, noise variance `sigma^2` per real dimension. Nearest-neighbor distance `d = |1 - w| = sqrt(3)`. Each symbol has 2 neighbors. By the union bound and the single-half-plane lower bound:

`Q(sqrt(3) / (2 sigma)) <= P_s <= 2 Q(sqrt(3) / (2 sigma))`

With `Es = 1`, `N0 = 2 sigma^2`: `sqrt(3)/(2 sigma) = sqrt(1.5 Es/N0)`, so `P_s ~= 2 Q(sqrt(1.5 Es / N0))`, which matches the general M-PSK approximation `2 Q(sqrt(2 Es/N0) sin(pi/M))` at M = 3. The upper bound is tight at high SNR because the two error half-planes overlap only far from the symbol.

[MC] check:

| sigma | Es/N0 | Monte Carlo P_s | lower Q | upper 2Q |
|---|---|---|---|---|
| 0.30 | 5.56 | 0.00372 | 0.00195 | 0.00389 |
| 0.50 | 2.00 | 0.07390 | 0.04163 | 0.08326 |
| 0.70 | 1.02 | 0.17989 | 0.10801 | 0.21602 |

**Pure phase jitter** (amplitude exact, `theta ~ N(0, s^2)`). Error iff `|theta mod 2pi| > pi/3`, so

`P_s = P(|theta| > pi/3) - (wrap corrections) <= 2 Q(pi / (3 s))`

The wrap correction (mass that goes past `5pi/3` and lands back in the correct sector) is negligible for `s < 1`. [MC]: `s = 0.3`: 0.000469 vs 0.000482; `s = 0.5`: 0.036236 vs 0.036225; `s = 0.2`: both below `10^-6`.

**Combined.** For small independent jitter and AWGN, CONJECTURE: `P_s <= 2 Q((pi/3 - delta) / s) + 2 Q(sin(delta) / sigma)` for any `0 < delta < pi/3`, by splitting the 60-degree margin between the two noise sources (the AWGN term treats the angular margin `delta` as a perpendicular distance `sin(delta)` on the unit circle). Not validated here.

### 6.4 What does not map

Z3 multiplication is **not** phasor multiplication: phasor multiplication is Z3 addition. `ab` corresponds to `w^{ab} = (w^a)^b`, which is **exponentiation** of one phasor by the other's digit.

- Multiplication by a known constant `b`: realizable as phase scaling by `b`. `b = 0`: output the constant 1. `b = 1`: identity. `b = 2`: phase doubling (a frequency doubler / second harmonic), which on mu3 equals complex conjugation because `w^{2a} = w^{-a}`. So in the phase domain, multiply-by-constant needs only identity, conjugation, or a constant source.
- Multiplication of two unknown phases: needs one operand as a digit (decoded) to select identity, conjugation, or constant. There is no single bilinear phasor operation for it. Honest statement: the phase domain realizes the additive group of Z3, not the field.

### 6.5 Link to the DFT over Z3

The characters of Z3 are `chi_k(a) = w^{k a}`, `k in Z3`. The 3-point DFT matrix `F = [w^{jk}]` is the character table. Group convolution over Z3, `(f * g)(c) = sum_{a + b = c mod 3} f(a) g(b)`, is diagonalized by `F`: `F(f * g) = (F f) . (F g)` pointwise. Phase encoding therefore gives the Fourier side "for free" in a coherent physical system; this is the basis for why interference-based hardware computes group convolutions. CONJECTURE: nothing here survives noise without error-correction overhead comparable to Section 6.3's margins.

---

## 7. Residue number systems (H6)

### 7.1 CRT

For pairwise coprime `m_1..m_k`, `M = prod m_i`, the map `x -> (x mod m_1, ..., x mod m_k)` is a ring isomorphism `Z_M ~ Z_{m_1} x ... x Z_{m_k}`. Reverse conversion:

`x = (sum_i r_i M_i (M_i^{-1} mod m_i)) mod M`, `M_i = M / m_i`.

Example `x mod 6 <-> (x mod 2, x mod 3)`: `M_1 = 3`, `3^{-1} mod 2 = 1`, coefficient 3; `M_2 = 2`, `2^{-1} mod 3 = 2`, coefficient 4; `x = (3 r_1 + 4 r_2) mod 6` [ENUM all 6].

| x | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| (x mod 2, x mod 3) | (0,0) | (1,1) | (0,2) | (1,0) | (0,1) | (1,2) |

Dynamic range: `M` values; signed use takes `[-M/2, M/2)` (or `[-(M-1)/2, (M-1)/2]` for odd M).

### 7.2 Cheap and hard operations

Cheap (carry-free between channels, each channel independent, parallel): `+`, `-`, `*`, multiply by a constant, and equality to a known constant (compare all residues). **Everything that needs magnitude is hard**:

- magnitude comparison, sign detection (signed range), overflow detection: the residues carry no positional information; answering requires (partial) reverse conversion.
- division, scaling by a non-modulus, rounding: require base extension or conversion.
- overflow is silent: in `{2, 3}`, `4 + 3 = 7` gives `(1, 1)`, which decodes to 1.

Reverse conversion cost:

- CRT form: k multiplies by constants of width `log2 M`, a k-term sum of width about `log2 M + log2 k`, and a final reduction mod M. For large M this is big-integer arithmetic.
- Mixed-radix conversion (MRC): computes digits `x = a_1 + a_2 m_1 + a_3 m_1 m_2 + ...` sequentially using only small modular ops, about `k(k-1)/2` modular multiply-subtracts, depth `k - 1`. Cheaper in width, serial in depth. MRC digits also allow comparison (compare digits from the top).

### 7.3 Special moduli

`{2^k - 1, 2^k, 2^k + 1}`: pairwise coprime (the two odd moduli differ by 2 and are odd, so gcd 1; both are odd so coprime to `2^k`). `M = 2^k (2^{2k} - 1)`, about `3k` bits (`k = 8`: M = 16,776,960, 24.0 bits). Channel `2^k` is plain truncation; `2^k - 1` uses end-around carry; `2^k + 1` uses diminished-one or similar tricks. Adder-based reverse converters for this set exist (prior art to verify for the specific best design).

Example `k = 3`, moduli `{7, 8, 9}`, M = 504, CRT coefficients 288, 441, 280 [ENUM]:
`11 -> (4, 3, 2)`, `13 -> (6, 5, 4)`, `11 * 13 = 143 -> (4*6 mod 7, 3*5 mod 8, 2*4 mod 9) = (3, 7, 8)`, and `143 mod (7,8,9) = (3, 7, 8)`. Check: `(288*3 + 441*7 + 280*8) mod 504 = 143`.

### 7.4 Hybrid binary/ternary channels

Moduli `2^a` and `3^b` are coprime. The `3^b` channel can be realized as b-trit balanced ternary with wrap mod `3^b`. Example: `2^32 x 3^20 = 1.497562e19`, about 63.7 bits, so a 32-bit binary channel plus a 20-trit channel spans nearly a 64-bit range. Reverse conversion still needs CRT/MRC across a binary and a ternary channel.

### 7.5 Prediction for ternary-weight x int8 dot: RNS loses

For `n <= 16,777,215` the exact result fits int32 (Section 4.2). A native 32-bit add is one instruction with carry propagation done in hardware at no extra cost. RNS with `k >= 2` channels does at least `k` channel adds per term (plus modular reduction per add, or deferred reduction with its own range bookkeeping), and the consumer of the dot product (requantize, ReLU, threshold, argmax) needs magnitude, which forces reverse conversion per output. Cost is at least `k` times the binary cost plus conversion; there is no carry chain to save. PREDICTION: RNS loses by at least a factor `k` for this workload on the Spark CPU.

Where RNS could win (to be gated, not assumed):

- long chains of add/multiply with no comparison until the end, whose exact result exceeds 64 bits (big-integer products, exact high-precision dot products);
- modular arithmetic that is already the semantics: hashing mod m, cryptographic modular multiplication, homomorphic encryption and lattice arithmetic mod a composite q;
- hardware where carry propagation is the critical path (wide adders), letting channels run in narrow parallel lanes.

---

## 8. Mixed-algebra realization (H7)

### 8.1 Definitions

Let `S : X -> Y` be a semantic operation, `D subset X` a declared input domain, and `C` a contract (Section 1.1).

- **Exact realization.** A tuple `(enc, g, dec)` such that for all `x in D`: `dec(g(enc(x))) = S(x)`, or the realization raises the contract's flag. The realization **is** `S` on `D`; the semantic identity (program id) is unchanged.
- **Approximate transform.** A new semantic operation `S'` together with an error bound `eps` and a metric `d` such that `d(S'(x), S(x)) <= eps(x)` for all `x in D`, and a provenance record `(source op id, transform id, transform parameters, bound, evidence)`. `S'` gets **a new semantic identity**. It is never a realization of `S`.

Float-to-ternary quantization is always an approximate transform. With `W ~ alpha W_t` (`W_t` ternary, scale `alpha`), the transformed op is `S'(x) = alpha W_t x`, with `|S'(x) - S(x)| <= ||W - alpha W_t|| ||x||` in any consistent operator norm. After the transform, the **integer** dot `W_t x` may have exact realizations (masked add, bitplane, int8 sdot) and these are exact relative to `S'`, not `S`.

### 8.2 Equivalence evidence levels

| Level | Name | Meaning | When allowed |
|---|---|---|---|
| E4 | proof | derivation (or checked proof) that `dec . g . enc = S` on `D` | any domain |
| E3 | exhaustive | every `x in D` tested | `|D|` small (for example all 9 trit pairs, all 243 bytes, all `3^10` 10-trit strings) |
| E2 | differential with coverage | reference vs candidate on a generated suite with stated coverage targets (all boundary values: 0, +-1, extremes of range, overflow edge `n = 2^24 - 1` and `2^24`, all (1,1)-fault paths) | large domains, integer ops |
| E1 | statistical | N independent random inputs, zero failures, gives failure probability `p <= -ln(a)/N` at confidence `1 - a` (from `(1 - p)^N <= a`); `a = 0.05` gives `p <= 2.996/N` ("rule of three") | approximate transforms, float realizations with bounds |
| E0 | none | not admissible for a realization claim | never |

An exact realization of an integer op should reach E3 or E4 on the per-element core (trit ops) and E2 on the composed kernel. An approximate transform must state `eps` and reach at least E1 against that bound.

### 8.3 What the algebra classifier extracts

For each operation node:

1. **Linearity**: linear, affine, bilinear, or nonlinear; and over which ring (Z, Z_m, R-with-float-rounding).
2. **Algebraic laws actually relied on**: associativity, commutativity, distributivity. For float nodes these are false and the node must record whether its reduction order is fixed or its result is only bounded.
3. **Coefficient set**: for example `{-1, 0, 1}`, int8, powers of two, arbitrary float.
4. **Sparsity**: fraction of zero coefficients, and structure (unstructured, block, N:M).
5. **Precision** of inputs and outputs.
6. **Dynamic range** of intermediates: max reduction length times max term magnitude (decides int16 vs int32 vs RNS).
7. **Exactness contract**: EXACT, WRAPPING mod m, BOUNDED with `eps`.
8. **Order dependence**: does the op or its consumer need comparison, sign or magnitude (kills RNS and Z3 candidates).
9. **Periodicity**: is the semantics defined modulo m (enables Z3/Z_m/phase candidates).

### 8.4 Candidate-realization table for six example ops

| # | Op | Classifier output | Exact candidates | Rejected candidates (reason) |
|---|---|---|---|---|
| 1 | GEMV with ternary weights, int8 activations | bilinear over Z; coeffs {-1,0,1}; range `128 n`; needs magnitude downstream | int8 sdot/i8mm on decoded trits; masked add/sub on 2-bit planes; base-3 packed + LUT decode; sparse index lists if density low | Z3 (wrap is wrong); RNS (Section 7.5); phase (additive only mod 3) |
| 2 | Long int accumulation (sum of int8 over n) | linear over Z; range `128 n` | int32 if `n <= 2^24 - 1`; int16 partials flushed every `<= 255` terms; int64 beyond | Z3, phase; RNS only if range exceeds 64 bits and no comparison until end |
| 3 | Threshold / gating (`y = x > t ? x : 0`) | nonlinear; needs order | binary/int compare; balanced-ternary compare from most significant nonzero trit | RNS (comparison needs conversion), Z3 and phase (no order) |
| 4 | Softmax-like (exp, sum, divide) | nonlinear; float; BOUNDED only | float with fixed reduction order and declared bound; integer lookup approximations only as **approximate transforms** with `eps` | any exact integer/ternary realization (none exists); quantized variants must get a new identity |
| 5 | Hash / parity mod 3 | linear over Z3; WRAPPING mod 3 | bitplane half-adder sum without carry; integer sum then mod 3; phase accumulation (physical) | none of the integer-only candidates is wrong, but integer-then-mod needs overflow margin |
| 6 | Z3 convolution (polynomial product in GF(3)[x], length L) | bilinear over Z3 | bitplane: H2 mul + carry-free half-adder sum per output; integer convolution with `|terms| <= 1` then mod 3 (exact if `L <= 2^31 - 1`); 3-point DFT via phases only for group convolution over Z3 | signed bounded ints without final mod (Section 5.1 counterexample) |

---

## 9. Win/lose summary

| Representation | Wins when | Loses when | Status |
|---|---|---|---|
| Balanced ternary digits (serial, arithmetic) | negation-heavy code, rounding to powers of 3 (truncation = rounding, double rounding safe), symmetric ranges | on binary silicon generally (each trit costs 2 bits or a decode); comparisons need a scan; radix economy does not apply to CMOS | proven properties; performance unproven |
| Bitplanes (P, N) | trit x trit dot (popcount), mul/neg/min/max by a few gates on 64 lanes | ternary x int8 (need expansion); storage (2 bits per trit vs 1.585) | formulas proven |
| 2-bit packed ternary weights | batch-1 memory-bound GEMV if decode sustains `4B` weights/s | compute-bound or cache-resident regimes vs native int8 sdot/i8mm; decode-limited kernels | PREDICTION |
| Base-3 packed (5 trits/byte) | memory-bound and decode sustains `5B`: up to 1.25x over 2-bit | decode-limited (LUT per byte); random access to single trits | PREDICTION |
| Sparse index lists | density below `2/b_idx` vs 2-bit (12.5% at 16-bit indices) | dense ternary (typical density above that); gathers on large x | PREDICTION, CONJECTURE on threshold |
| Z3 | semantics already mod 3 (GF(3) codes, mod-3 hashes) | any integer semantics (1+1 must be 2), anything with order | proven |
| Phase (mu3) | physical coherent hardware for Z3 addition, group convolution | Z3 multiplication of two unknowns; noise (Section 6.3) | math proven; hardware out of scope |
| RNS | long mul/add chains beyond 64 bits with no comparison; modular semantics | anything fitting int32/int64; anything needing sign/compare/scale | PREDICTION |
| Floats (IEEE, BF16, FP8, NVFP4) | real-valued approximate semantics with bounds | any exact identity; reordering without a bound | non-associativity verified |

---

## 10. Test vectors

All values below were produced or checked by `theory/check.c` [ENUM].

### 10.1 Integer to balanced ternary (MSB first, `T` = -1)

| x | canonical bt | trits |
|---|---|---|
| 0 | `0` | 1 |
| 1 | `1` | 1 |
| -1 | `T` | 1 |
| 2 | `1T` | 2 |
| 5 | `1TT` | 3 |
| 13 | `111` | 3 |
| -13 | `TTT` | 3 |
| 40 | `1111` | 4 |
| 121 | `11111` | 5 |
| -121 | `TTTTT` | 5 |
| 364 | `111111` | 6 |
| 1743392200 = (3^20 - 1)/2 | `11111111111111111111` (20 ones) | 20 |
| 3486784401 = 3^20 | `1` followed by 20 zeros | 21 |

Note: `3^20` does not fit in 20 trits; the largest 20-trit value is `(3^20 - 1)/2`.

### 10.2 Trit ops (value in, value out)

| a | b | a*b | half-adder (s, c) | Z3 sum (carry dropped) |
|---|---|---|---|---|
| +1 | +1 | +1 | (-1, +1) | -1 (= 2 mod 3) |
| +1 | -1 | -1 | (0, 0) | 0 |
| -1 | -1 | +1 | (+1, -1) | +1 |
| 0 | -1 | 0 | (-1, 0) | -1 |
| +1 | 0 | 0 | (+1, 0) | +1 |

Multi-trit addition: `111 + 001 = 1TTT` (13 + 1 = 14; full carry chain).
Truncation: `x = 40 = 1111`; delete 1 trit: `111` = 13 = round(40/3 = 13.33); delete 2: `11` = 4 = round(40/9 = 4.44). `x = 14 = 1TTT`; delete 1: `1TT` = 5 = round(4.67).

### 10.3 Block dot (bitplanes, lane 0 = least significant bit)

8 lanes, `x = [+1, -1, 0, +1, -1, +1, 0, -1]`, `y = [+1, +1, -1, -1, -1, 0, +1, -1]`:

- `xP = 0b00101001`, `xN = 0b10010010`; `yP = 0b01000011`, `yN = 0b10011100`.
- `xP&yP = 0b00000001` (1), `xN&yN = 0b10010000` (2), `xP&yN = 0b00001000` (1), `xN&yP = 0b00000010` (1).
- `dot = 1 + 2 - 1 - 1 = 1`. Direct: `1 - 1 + 0 - 1 + 1 + 0 + 0 + 1 = 1`.

Ternary x int8: `w = [+1, -1, 0, +1]`, `x = [100, -128, 7, 127]`: `100 + 128 + 127 = 355`. Overflow edge: `n = 2^24`, all `w = -1`, `x = -128` gives `2^31` (overflows int32); `n = 2^24 - 1` gives `2^31 - 128` (fits).

### 10.4 Z3

`1 + 1 = 2`, `2 + 2 = 1`, `2 * 2 = 1`, `1 * 2 = 2`, `0 * 2 = 0`, `-(1) = 2`. Through `phi`: `2 * 2 = 1` <-> `(-1)(-1) = 1` (agree); `1 + 1 = 2` <-> `1 + 1 = -1` in balanced mod-3 residue, but `2` in Z (disagree).

### 10.5 Five trits per byte

Packing rule, trit `t_0` least significant: `byte = sum_{i=0}^{4} (t_i + 1) 3^i`, which equals `value(t) + 121` [ENUM, all 243 codes]. Codes 243..255 (13 codes) are invalid and must fault.

| trits `[t_0..t_4]` | balanced value | byte |
|---|---|---|
| `[0, 0, 0, 0, 0]` | 0 | 121 |
| `[1, 1, 1, 1, 1]` | 121 | 242 |
| `[-1, -1, -1, -1, -1]` | -121 | 0 |
| `[1, 0, -1, 0, 1]` | 73 | 194 |
| `[-1, 1, 0, 1, -1]` | -52 | 69 |

### 10.6 CRT

- `{2, 3}`: `5 -> (1, 2)`; reverse `(3*1 + 4*2) mod 6 = 11 mod 6 = 5`. Silent overflow: `4 + 3 -> (1, 1) -> 1`.
- `{3, 5, 7}`, M = 105, coefficients 70, 21, 15: `52 -> (1, 2, 3)`; reverse `(70 + 42 + 45) mod 105 = 157 mod 105 = 52`.
- `{7, 8, 9}`, M = 504, coefficients 288, 441, 280: `100 -> (2, 4, 1)`; `11 * 13 = 143 -> (3, 7, 8)`.

### 10.7 Float non-associativity vectors

As in Section 1.4. A realization claiming equivalence to a float reference must reproduce the reference grouping on these inputs, or state a bound that covers both groupings.

---

## Appendix A. Independent check by Grok

One Grok (CLI, single-turn, reasoning only) pass on 2026-09-29 checked five claims:

| # | Claim | Grok | Notes |
|---|---|---|---|
| 1 | 3-PSK AWGN bounds `Q(sqrt3/(2 sigma)) <= P_s <= 2Q(sqrt3/(2 sigma)) = 2Q(sqrt(1.5 Es/N0))` | AGREE | Grok's estimate at `sigma = 0.5`: 0.0738, matching the Monte Carlo 0.0739 |
| 2 | Phase jitter `P_s ~= 2Q(pi/(3s))`, wrap negligible | AGREE | 0.0362 at `s = 0.5`, matching Monte Carlo |
| 3 | int32 safe iff `n <= 16,777,215` | AGREE | same edge `2^31` at `n = 2^24` |
| 4 | truncation = nearest rounding, no ties, double rounding composes | AGREE | same tail-bound argument |
| 5 | carry propagates w.p. 1/3 in ternary "vs 1/2 in binary" | **DISAGREE** (correctly) | the binary conditional `P(c_out | c_in)` is 3/4, not 1/2; 1/2 is the pure-propagate probability. Section 2.5 was corrected and re-verified by enumeration (ternary 3/9 continuation, 2/9 pure propagate; binary 3/4 and 2/4) |

## Appendix B. Reproduction

The checks live in the job scratch directory `theory/check.c`, `theory/dr.c` and `theory/carryprob.c` (C, `gcc -O2 ... -lm`). `check.c` exits nonzero on any failed assertion; the recorded run reported `fails=0`. These programs are verification aids only and are not part of any repository.
