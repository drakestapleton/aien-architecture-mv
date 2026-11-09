# Omegese correctness and GB10 decode speed: research notes

Date: 2026-10-15. Author: Sonnet 5.5 research worker (Haiku 5.5 helpers extracted facts from papers; every number
used for a recommendation was re-checked by me against the paper text, source code or NVIDIA page unless marked `H`).
Scope: two live bets of the AIEN project, the Omegese language and my own GB10 inference engine.
Not covered: anything that needs the GPU (none was used) or any edit to other repos.

Tags: PROVEN = a primary source says it (URL plus section, page or file:line). INFERRED = my reasoning from proven facts.
UNKNOWN = not established, with the cut that would retire it. `H` = read through a helper's page summary, not independently
re-read by me; treat quotes and exact digits as unverified until checked. Arithmetic uses the `aien-calc` tool (calc ids given).

## Summary

Two findings change the plan more than any paper does.

1. PROVEN (code): `omegese next` is not yet a full mask. For most line positions it prints the fallback
   `words: (any word of the line form; see OMEGESE.md)` (`tools/omegese/omegese.c:986`, at omega-glyph d1cee83). It gives exact sets only
   after `ret`, after `if`/`while`, and for a binary op's second operand (`:929-985`). The mask idea is sound, but the
   mask itself still has to be written.
2. INFERRED (arithmetic on proven sizes): if every Omegese terminal is one token and names come from a closed pool, the legal set at every
   position is a few hundred token ids. Then the engine does not need a 152k-row mask. It can compute logits only for the
   legal rows, which skips most of the output-head read: 18.5 percent of the bytes read per token on the 30B FP8 model
   (calc:d110be7b), 8.2 percent on the dense 8B bf16 (calc:7f29a211 from the design note), and 28.6 percent on a 30B NVFP4 model (calc:fb853368).

Top 10 recommendations, ranked by expected benefit per unit of work. Impact is a tag-qualified estimate, not a measurement.

| # | Recommendation | Expected impact | Effort | Main sources |
|---|---|---|---|---|
| 1 | Make the trial statistically able to see a difference: held-out 60 tasks x 3 attempts, paired, 2x2 grid (mask on/off x 1-shot vs many-shot), report "accepted by checker2" and "passes tests" separately | Today 3/10 has a 95% interval of about 11-60% (hand-computed Wilson), so 2/10 vs 3/10 says nothing. Prevents wrong decisions. | Low | EXP445_PROTOCOL.md:30,59; section 1.7 |
| 2 | Replace the one-example prompt with a static prefix of 12-16 worked examples plus a one-page word card, cached by the engine's persistent prefix KV | INFERRED large on first-attempt accuracy; literature: Grammar Prompting +6 points over few-shot and +27 on unseen functions (`H`); prompt cost near zero after the first prefill | Low | section 1.4; Wang 2023; 2409.19151; 2606.16827 |
| 3 | Finish `omegese next` into an exact, completable automaton (line-form state x type environment) and fuzz it for "never an empty legal set" | The mask does what the spec promises. In the strongest type-constraint paper, 94% of compile errors were type errors, 6% syntax. | Low-Medium (CPU C) | omegese.c:929-1000; Mündler 2025 lines 56-70 |
| 4 | Close the token alphabet: names drawn from a pool of single-token words, one canonical line terminator, numbers digit by digit | Removes the token-boundary distortion class (naive constraint cost 10.7 points on GSM8K in DOMINO) and makes forced tokens canonical | Low (language) | section 1.3; DOMINO 2403.06988 s2; llguidance fast_forward.md |
| 5 | Sparse output head: compute logits only for the legal token rows, in the engine's decode list | 30B FP8: 63 to 77 tok/s on the 212 GB/s line (+22.6%, calc:062a5228); 8B bf16: 14.0 to 15.3 (+9%, calc:ee08753a). Bigger share with 4-bit weights. | Medium (one new GEMV variant with a row list) | section 2.2; design note 2.1 K0 |
| 6 | Fix the sampler (identical text across seeds) before any pass@k or resampling work, and test it against reference formulas | Without it, "k attempts" are one attempt. Reference orders differ; see section 3. | Low | section 3 |
| 7 | 8B: use the official Qwen3-8B-FP8 checkpoint instead of bf16 | Weight bytes halve: ceiling 14.0 to 28.0 tok/s at 212 GB/s (design note calc:f2f6c2f6). It is the vendor's quantisation, so no "our own quantisation" qualification. | Medium (dense FP8 GEMV; the MoE one exists) | Qwen3-8B-FP8 card `H`; 2411.02355 `H` |
| 8 | 8B speculative decoding with free drafts first: grammar-forced tokens plus prompt/n-gram lookup over the few-shot prefix; EAGLE-3 head later | Dense verify step costs about one decode step (INFERRED); at acceptance 0.7 and 4 drafts, 2.77 tokens per step (Leviathan Eq 1). EAGLE-3: 2.36x at batch 1 on H100, 8B. Measure acceptance offline first. | Medium (lookup) / High (EAGLE) | section 2.4 |
| 9 | 30B MoE: first find where the 38-43 tok/s goes (it sits at 47-53% of the 273 GB/s line), then NVFP4 weights; do not start with speculative decoding | NVFP4 cuts bytes 35% (3.37 to 2.18 GB); NVIDIA's own best engines reach about 55-70% of the line, so realistic headroom is +15-30%, not 2x. MoE verify costs 2-3x a step. | High | sections 2.2-2.4 |
| 10 | Repair loop: at most 2 rounds, feedback = checker reason plus a failing test's input/expected/got; with the mask on, drop syntax and type repairs | Most repair gain arrives in rounds 1-2 (87% of the 4-round gain at round 2 for Llama 3.1 8B). Resampling is about as good at equal budget. | Low | section 1.5 |

Weakest or UNKNOWN claims (details in section 4): the share of Omegese positions that have exactly one legal word; whether
the verify step of a dense 8B on my kernels costs about one decode step (no primary source measures k up to 8, and my old prefill
runs at 6.1 ms per token); the acceptance rate of lookup drafts on Omegese; why the server returns identical text across seeds
(the one-list graph's argmax is a candidate, not a finding); GB10's dense FP8/FP4 TFLOPS (NVIDIA publishes only "1 PFLOP FP4"); FP6
accuracy on Qwen; the Mündler paper's quoted overhead is for an unoptimized Python prototype.

---

## 1. Getting a model to write a language it has never seen

### 1.1 What the project has today (ground truth)

- PROVEN `docs/one_layer/OMEGESE.md` s2: one word is one Qwen3 token (with its leading space), types inferred, names not registers, structured
  control, loops proven to end, prefix-decidable, same trust chain (op list, binary IR, checker2, signed receipt). s5: 449 tokens over the 10 dev tasks vs 661 for text and 4210 for the op list.
- PROVEN s7: first prompt-only trial, 30B on my engine, one attempt: Omegese 3/10, text 3/10, structured 0/10; completion tokens 1015 / 1346 / 12027. 8 of 10 first answers were refused only for writing `u8`/`u32` (now accepted).
- PROVEN `docs/one_layer/EXP445_PROTOCOL.md:30`: all arms show the same single worked example (`clamp_sub`). So the trial measures roughly 1-shot.
- PROVEN `EXP445_PROTOCOL.md:117-119`: sampling is T=0.7, top_p=0.8, `seed = 445000 + 1000 x attempt + task index`; the protocol was validated on MAX (`:158`), not on my engine.
- PROVEN `tools/omegese/omegese.c:929-1000`: `next_words` is "coarse classes plus names" (its own comment at `:915`), with the fallback at `:986`.

### 1.2 What constraining the output buys, as measured

| Evidence | Result | Source |
|---|---|---|
| Type-constrained decoding, TypeScript, 6 open models 2B-34B, HumanEval + MBPP | Compile errors down 74.8% (HumanEval synthesis) and 56.0% (MBPP); syntax-only constraint would give 9.0% and 4.8%. Pass@1 up 3.5% (synthesis), 5.0% (translation), 37.0% (repair), relative. Median runtime +39.1% / +52.1%, but in an unoptimized Python prototype. PROVEN | Mündler et al., https://arxiv.org/abs/2504.09246 , Table 2 caption (pdf text l.835-838), s5.2 (l.883-940), Table 4 (l.947-970) |
| Same paper: where errors come from | Syntax is 6% of compile errors, type failures 94%. PROVEN | same, l.56-66 |
| SynCode (LR(1) parser + DFA mask store) | 96.07% of syntax errors removed in Python and Go; JSON syntax errors 0 for Llama-2-7B-chat; SQL execution accuracy 32.6 to 41.6% for the same model. `H` | https://arxiv.org/abs/2403.01632 , abstract, Tables 1-2 |
| JSONSchemaBench, Llama-3.1-8B, GSM8K-in-schema | LM only 80.1, XGrammar 83.7, llguidance 83.8 (a few points of quality gain). `H` | https://arxiv.org/abs/2501.10868 , Table 8 |
| "Let Me Speak Freely?" | Strict JSON can hurt reasoning: GSM8K Claude 3 Haiku 86.51 to 23.44; GPT-3.5 75.99 to 49.25; Gemini 1.5 Flash unchanged. `H` | https://arxiv.org/abs/2408.02442 , Table 1 |
| CRANE | Free reasoning, switch to the grammar between delimiters: GSM-Symbolic up to +10 points over unconstrained CoT (e.g. Qwen2.5-Math-7B 29 to 38 vs CoT) `H` | https://arxiv.org/abs/2502.09061 , Tables 1-3 |

INFERRED reading for Omegese: the mask removes the "refused by the checker" failures and nothing else. After the type-name fix, the remaining failures will be
mostly semantic (wrong program), where a mask cannot help. Validity gain is large only if validity is the bottleneck; the trial must report both.

### 1.3 Mask distortion, token alignment, and why Omegese is a special case

**Distortion.** Plain grammar-constrained decoding (GCD) renormalizes the model's next-token distribution over allowed tokens at each step. Grammar-Aligned Decoding
shows this can bias the output: GCD replaces the "probability the model can still finish grammatically" term with 1 (Sec 2); in their Example 3, GCD ends in
the low-probability branch about 30% of the time vs about 90% for the model (PROVEN, https://arxiv.org/abs/2405.21047 , text l.551-575 of the PDF).
The fix, ASAp, learns those future-probabilities from earlier samples; on 36 CFG/SyGuS convergence tasks (Mistral-7B, 2000 samples) and, on the SLIA and INV-BV4 tasks, it gives correct samples 38% more often than GCD
(geometric mean), but 73% less often on the SLIA subset both solve, and the authors write "The key limitation of our work is the current slow convergence of the ASAp algorithm" and
that ASAp "has no strong effect on solving downstream tasks" (PROVEN, same PDF l.551-575; Sec 4).
INFERRED: do not build ASAp. Reduce the distortion where it comes from. Distortion is worst where the grammar allows a path that is likely under the model but almost never completes
validly. Omegese's checker rules (a name written must be read before its scope ends) are exactly that kind of "late" rule, so the mask should forbid `end` while an unread name exists, and a fuzz test
should confirm no prefix the mask allows has an empty legal set later (section 1.7, item B).

**Token alignment.** DOMINO reports that naive constraining forces unnatural tokenisations: GSM8K, Mistral-7B, 5-shot: unconstrained 41.5%, naive constrained 30.8%, minimally invasive 41.8% (`H`, https://arxiv.org/abs/2403.06988 , s2).
llguidance documents the same trap for forced tokens: forcing `order` before `Id` produces a token sequence the model almost never saw, and with token healing off "97%" of fast-forwarded sequences were non-canonical in
their Llama 3 test (PROVEN, https://github.com/guidance-ai/llguidance/blob/main/docs/fast_forward.md , whole file, and `H` for the 97% digit).
INFERRED: Omegese avoids this class by design when every fixed word is one token with its leading space, because the only tokenisation of a forced word is that token. The remaining holes are names (several tokens, many splits), digits, and the line terminator
(`\n`, ` \n`, `\n\n` are different token ids). Close them (section 1.7, item A).

**Mask cost, and how the fast systems get it.** The fast systems exist because their terminals are character strings and the vocabulary has about 128k entries, so a mask must be derived by walking every token against the grammar.

| System | How the mask is made cheap | Cost | Source (file:line) |
|---|---|---|---|
| XGrammar | Split tokens into context-independent (decided from the grammar position alone, precomputed per position) and context-dependent (checked at runtime with the stack). An "adaptive token mask" stores the smaller of accepted or rejected sets, or a bitset above 1000 entries. Persistent stack tree for cheap branching and rollback. Mask on CPU, overlapped with GPU. | Under 40 us per token for JSON and CFG-JSON, under 200 us for XML and a Python DSL (s4.1, Fig 9). Ablation: 65.8 ms with a plain pushdown automaton to 0.018 ms with all steps (Table 3). Only 1,134 of 128k tokens are context-dependent for Llama-3.1 JSON (s3.1). PROVEN | https://arxiv.org/abs/2411.15100 ; code `cpp/compiled_grammar_impl.h:40-61` (`AdaptiveTokenMask`, `USE_BITSET_THRESHOLD = 1000`), `cpp/grammar_compiler.cc:814` (`GetAdaptiveTokenMask`), `cpp/grammar_matcher.cc:1683` (`FillNextTokenBitmask`), `:521` (`FindJumpForwardString`) at 7e269d5 |
| llguidance | Flat token trie (about 2 x vocab nodes, about 13 cycles per node) walked against a lazily built regex-derivative lexer, with an Earley parser on lexemes; the parser touches under 0.5% of trie nodes. "Slicer" splits tokens by regex classes so large masks in unconstrained spans are cheap. | About 50 us average per token on a 128k tokenizer; a typical JSON-schema full mask about 1.5 ms (README, optimizations.md). PROVEN | https://github.com/guidance-ai/llguidance/blob/main/docs/optimizations.md ; code `parser/src/tokenparser.rs:493-504` (`compute_mask`), `:813` (`compute_bias`), `parser/src/earley/slicer.rs:382`, `toktrie/` at 6cef6ed |
| Outlines | Compile regex to a finite-state machine, precompute for every state the set of vocabulary tokens that keep the machine alive, look up per step. | O(1) average per token, memory proportional to number of states (s1, s3). PROVEN | https://arxiv.org/abs/2307.09702 |
| SynCode | Offline "mask store": DFA state plus a short terminal sequence to a vocabulary bitmask, unioned at runtime; LR(1) parser supplies the accept sequences; length 1-2 sequences make it sound but not complete. `H` | Store build under 10 min per grammar; JSON latency about equal to unconstrained. | https://arxiv.org/abs/2403.01632 |
| DOMINO | Subterminal trees aligned to the vocabulary, plus "opportunistic masking": check the model's proposed token first, build the full mask only if it is rejected. `H` | 4.21% overhead on free-form JSON; up to 1.77x unconstrained throughput on schema JSON by speculation. | https://arxiv.org/abs/2403.06988 s3.5-3.6, Tables 2-3 |
| Type-constrained (Mündler) | Sample a token, ask the completion engine whether it keeps the program well-typed, resample if not (Algorithm 1, line 4). Same distribution as masking. PROVEN | +39% median runtime in Python | https://arxiv.org/abs/2504.09246 s5.3 |
| Flexible and Efficient GCD | Reports 17.71x faster offline preprocessing than earlier approaches, keeping online masks competitive. `H` (abstract) | | https://arxiv.org/abs/2502.05111 |

INFERRED for Omegese: none of the heavy machinery is needed. My terminals are token ids. The legal set at a position is computed directly from the checker's state (line form, function table, name-to-type map)
in time proportional to the number of legal words, tens of microseconds at most on the host, against a 25 ms decode step. Mask cost is not a concern; mask correctness and the lm-head saving are.
The one XGrammar idea worth copying is the persistent (cheaply copyable and rollbackable) state, because speculative decoding needs to run the automaton down a draft chain and roll back (section 2.5).

### 1.4 Teaching a language the model has never seen, in context

| Evidence | Finding | Source |
|---|---|---|
| Grammar Prompting (Codex, DSLs, 16-32 examples per task) `H` | GeoQuery execution accuracy: standard few-shot 81.5, with the model first writing a specialized grammar 87.5, plus constrained decoding 88.9. Unseen-function split: 63.3 to 90.8. No gain for languages likely seen in pretraining (SQL, regex). | https://arxiv.org/abs/2305.19234 , Tables 1-2, Sec 4 |
| Kalamang grammar book in context (Gemini-1.5-Flash) `H` | chrF++ English to Kalamang: no examples 11.0, full book 34.4, parallel examples only 30.8, grammar explanations only 22.6. Conclusion: "no evidence" models exploit grammatical explanations. | https://arxiv.org/abs/2409.19151 , Table 2 |
| Gleam and MoonBit (new languages), 4 models `H` | Top-5 retrieved examples beat retrieval over documentation in 7 of 12 (Gleam) and 8 of 12 (MoonBit) cases; syntax errors down 15.36% with examples vs 8.94% with docs. | https://arxiv.org/abs/2606.16827 , Table V, Sec III |
| Low-resource R and Racket, DeepSeek 33B `H` | 2-shot in-context raised R pass@1 30.2 to 38.3 and Racket 32.5 to 36.3; "no specific technique results to be the best". | https://arxiv.org/abs/2501.19085 , Table III |
| Many-shot ICL (Gemini 1.5 Pro) `H` | Low-resource translation: +15.3% (Bemba) and +4.5% (Kurdish) at about 1000 shots over 1-shot; tasks plateau at very different counts (XSum about 50, MATH about 125). Result is order sensitive. | https://arxiv.org/abs/2404.11018 , s2.1, Figs 3-8 |
| Retrieved vs random examples, Zhuang `H` | BLEU 12.6 vs 9.2 and 19.5 vs 14.7 with retrieved examples; a stated rule alone was "largely ineffective". | https://arxiv.org/abs/2402.19167 , Table 4, Sec 6.2.2 |
| Fine-tuning route, for scale `H` | MultiPL-T: 15B OCaml 6.9 to 19.9, Racket 11.8 to 21.0, at about 9,984 A100 hours of training. | https://arxiv.org/abs/2308.09895 , Table 2 |

INFERRED answers to "how many examples, and examples versus grammar in the prompt":

- Concrete examples carry most of the gain; prose rules and grammar descriptions add less (Kalamang, Zhuang, Gleam). The Grammar Prompting gain came from examples that each show the grammar subset used, not from a pasted grammar.
- One example (my trial) is far below anything in the literature; every reported setup uses 5 to 32 examples. A reasonable first point is 12-16 diverse examples, one per construct (arithmetic, `if`/`else`, `while ... bound`, `for`, arrays with `new`/`get`/`put`/`free`, calls, nested expressions, `trap`), simplest first, the closest-to-task last. 16 programs of about 45 tokens plus requirement text is under 2k tokens.
- Cost is near zero after one prefill: the engine already has persistent KV and `reusable_prefix` (design note s1.1, `kv_persist.rs`), and a 2048-token prefill is about 0.85 s on the 30B. Keep the example block static so the prefix cache hits. Add at most 2-4 retrieved examples after it.
- A one-page word card (the roughly 60 fixed words, one line each, with types) is cheap, but treat it as secondary to examples.
- Show the task signature in Omegese spelling (`uint`, not `u32`), so the model never sees the foreign spelling. The refusal fix (accepting `u8`..`i64`) is a patch; the prompt can make it unnecessary.
- If prompt plus mask plateaus below target, the next lever is fine-tuning on checker-validated programs. My checker is a perfect validity oracle, so rejection-sampled self-training is possible. No source measures this for a language like Omegese; UNKNOWN.

### 1.5 Repair loops with compiler feedback

| Evidence | Finding | Source |
|---|---|---|
| Iterative self-repair, 7 models, HumanEval, 4 rounds (2026) | Cumulative pass@1, Llama 3.1 8B: 67.1, 73.2, 75.6, 76.2, 76.8 (rounds 0-4). Round 2 holds 87.6% of the 9.7-point total (calc by hand from Table I). Gemini 2.5 Flash 86.6, 95.7, 95.7, 96.3, 96.3. PROVEN | https://arxiv.org/abs/2604.10508 , Table I (pdf text l.191-215) |
| Self-Debug `H` | Successful debugging "mostly end within 3 turns"; on Spider one turn is enough. | https://arxiv.org/abs/2304.05128 , s5 |
| Is Self-Repair a Silver Bullet? `H` | At equal budget GPT-4 on APPS: 10 samples + 1 repair each = 1.05x pass@20 baseline; 2 samples + 10 repairs each = 0.97x. Feedback quality is the limit (GPT-4's own feedback was clearly wrong in 32 of 80 cases). | https://arxiv.org/abs/2306.09896 , Intro, Sec 4.3 |
| Cannot self-correct without external feedback `H` | GPT-4 GSM8K 95.5 to 91.5 to 89.0 over two self-correction rounds. | https://arxiv.org/abs/2310.01798 , Table 3 |
| Type constraints inside repair (Mündler) | Gemma 2 2B repairs 33.5% / 25.8% of non-compiling instances vanilla, 56.4% / 58.4% with type constraining. PROVEN | https://arxiv.org/abs/2504.09246 l.925-935 |

INFERRED: allow two repair rounds, as the protocol already does. Feed back the checker's refusal text only while the mask is off; with the mask on, syntax and type refusals cannot occur, so the useful feedback is a failing test's input, expected and actual output.
Models do not fix reasoning without outside signal, so a repair prompt with no test result is wasted tokens. At equal token budget, a fresh sample is about as good as a repair, which is one more reason to fix seeding first (section 3).

### 1.6 Prior art note for the spec's "new" claim

Spec s8 says "new" is UNVERIFIED. I found nothing contradicting it, and nothing confirming it. The nearest items: Mündler (type-aware prefix automata, TypeScript, token-agnostic), SimPy (grammar redesigned for fewer tokens, https://arxiv.org/abs/2404.16333 , 13.5% fewer tokens for CodeLlama; accuracy shown only by training 350M-1.1B models from scratch, so no evidence for prompting; `H`),
and Decode-Time Grammars (https://arxiv.org/abs/2607.18357 , languages TileLang, SQL, P4; abstract only, `H`). None chooses terminals as single vocabulary tokens. Keep the claim UNVERIFIED.

### 1.7 Concrete recommendations for Omegese

**A. Language design (all INFERRED unless a source is named).**
1. Closed token alphabet. Allow names only from a pool of single-token, leading-space words (a few hundred; check with the tokenizer gate already in `make test-omegese`). One canonical line terminator token; accept others at the parser but never offer them in the mask. Numbers stay digit by digit. After this the language is a finite automaton over token ids, with no tokenisation ambiguity and no non-canonical forced tokens.
2. One spelling per construct in the mask. Today `x = v` and `x v` both parse (OMEGESE.md s3). Two spellings split probability mass between equivalents and give the few-shot examples two conventions. Pick the short form for generation (it saves 32 tokens over 10 dev tasks, 449 vs 417 in s5) and keep both in the parser.
3. Nested prefix expressions (in progress): safe for prefix decidability because arity is fixed. The state is a stack of pending operand slots with their expected types; the mask at each slot is the names and ops giving that type. Two untyped numbers (`add 1 2`) must be masked out, since a number takes its type from the other operand.
4. Make the "name must be read" rule a mask rule: while any name is unread, `end` and the function-closing words are masked out unless a read of that name is still reachable. Add a fuzz check that no allowed prefix reaches an empty legal set (GAD dead-end concern).
5. Optional: a delimited free-text planning span before the program (CRANE pattern: free text, a delimiter token, then the mask switches on). Evidence says strict formats can hurt reasoning, but the cited drops are for JSON answers to math, not code. Add only if the trial shows reasoning loss; it costs tokens and an unconstrained region in the engine.

**B. Mask design inside my engine.**
1. Host-side exact automaton first. State = (function table, name-to-type map, frame stack, line-form state). Copying it costs well under a kilobyte per token; use copy-on-write or an undo log so speculative drafts can roll back. Output = list of legal token ids (and a "forced" flag when the list has length 1).
2. Sparse output head: the host writes the legal ids into a small device buffer before the output-head launch; the head GEMV reads only those rows (row list instead of rows 0..151935). Masked softmax over those rows is mathematically the masked softmax over the full vocabulary (INFERRED, since all other logits become minus infinity). Sizes: 30B head 622 MB of 3.365 GB per token (calc:d110be7b); 8B head 1.24 GB of 15.14 GB. Where the span is unconstrained, fall back to the full head.
3. Forced positions (exactly one legal id): skip the sampling and the head entirely; append the token and feed it as an extra row to the next decode pass. This equals speculative decoding with 100% correct drafts (llguidance docs say so in nearly these words: "similar to speculative decoding, except that the speculation is 100% correct"). On the dense 8B the extra row is nearly free; on the 30B MoE it costs extra experts (section 2.4).
4. The per-token host round trip is already in the one-list design (token read back, new list launched, about 0.3 ms host per the design note s3). The mask update rides on it. A GPU-resident table, as the brief suggested, would only pay if profiling shows that round trip matters; the type environment makes a static table large and awkward.
5. Do not copy the vocabulary-trie machinery. Do copy the test method: XGrammar and llguidance both validate masks against a slow reference over many prefixes; do the same, comparing the engine's list to `omegese next` on thousands of generated prefixes.

**C. Prompt design.** Section 1.4 (12-16 static examples, word card, Omegese-spelling signatures, cached prefix, 2-4 retrieved examples last).

**D. Trial protocol.**
1. n: 3/10 has a 95% Wilson interval of roughly 11% to 60% (hand arithmetic: centre 0.356, half-width 0.248). The 10-task trial cannot distinguish 2/10 from 3/10. Use the 60-task held-out set with 3 attempts per task, paired by task.
2. Grid: {text, Omegese} x {1-shot, 12-16-shot} x {mask off, mask on}. Pre-register it. Compare paired with McNemar on attempt-1 success.
3. Report separately: checker2 ACCEPT, tests pass, refused-by-reason counts, completion tokens, wall time per accepted program.
4. Seeds: the protocol's seed rule needs a working sampler; fix it and add a regression test that two seeds give different text at T=0.7 (section 3). Until then, greedy (T=0) is the only trustworthy setting.
5. Re-run the owed rerun (type-name fix) before any other change, to get a clean baseline for the new grid.
6. Save every raw completion and the legal-id list at each position; this gives the free forced-token ratio (UNKNOWN today) and a corpus for measuring lookup-draft acceptance offline (section 2.4).

---

## 2. Decode speed on GB10 for my own engine

### 2.1 What GB10 really offers

| Fact | Value | Tag and source |
|---|---|---|
| Memory | 128 GB LPDDR5x, unified, 256-bit, 273 GB/s | PROVEN https://docs.nvidia.com/dgx/dgx-spark/hardware.html , System Overview and Performance Specifications (read directly). Also derived in `docs/research/dgx-spark-hardware-audit-m15.md:265` as 256 bits x 8533 MT/s. |
| GPU | Blackwell, 6,144 CUDA cores, 5th-gen tensor cores with FP4 | PROVEN same page |
| Headline compute | "up to 1 PFLOP at FP4 precision with sparsity" (docs page); product page says "Up to 1 PFLOP FP4" without the qualifier `H` | PROVEN docs page; the qualifier difference is `H` https://www.nvidia.com/en-us/products/workstations/dgx-spark/ |
| Per-precision FP8, BF16, dense FP4 TFLOPS | Not published on either NVIDIA page I read | UNKNOWN. Dense FP4 is 500 TFLOPS if the 1 PFLOP is the 2:1 sparse figure (INFERRED). A forum user reports 356 TFLOPS dense NVFP4 GEMM on SM121 after a CUTLASS patch (unverified, not NVIDIA documentation). |
| My measurements | m=1 matmul 207-218 GB/s; bf16 GEMV 212 GB/s; one L2-resident GEMV probe 236-268 GB/s; FP8 QMMA prefill 24.6 TFLOPS | PROVEN in `~/handoffs/2026-10-15-own8b-design.md` s3 (cites FINDINGS.md:511 and omega evidence logs) |
| NVIDIA's own decode numbers, batch 1, 2048 in / 128 out | Llama 3.1 8B NVFP4 TRT-LLM 38.65 tok/s (prompt 10,257 tok/s); Qwen3 14B NVFP4 22.71; GPT-OSS-20B MXFP4 llama.cpp 82.74; GPT-OSS-120B 55.37 | PROVEN `H` https://developer.nvidia.com/blog/how-nvidia-dgx-sparks-performance-enables-intensive-ai-tasks (24 Oct 2025), Table 4. No FP8 or BF16 rows. |
| Tensor-core instruction set | The older warp-level `mma.sync` family is what PTX lists for sm_121a, including block-scaled FP4 (`.kind::mxf4nvf4`, `.kind::mxf4`), and FP6/FP4 operand types for sm_120a and its family. The datacenter `tcgen05` path is not listed for sm_120a/sm_121a. Static shared memory per block is 100 KB on sm_120a/sm_121a vs 228 KB on sm_100a/sm_90a. | PROVEN PTX ISA 9.4, https://docs.nvidia.com/cuda/parallel-thread-execution/index.html : s5.1.7 shared-memory table; mma text "Qualifiers .kind::mxf4nvf4 and .kind::mxf4 are supported on following architectures: sm_120a, sm_121a" and ".e3m2, .e2m3 and .e2m1 ... supported on sm_120f or higher in the same family" (read in full-page text; that sm_121 belongs to the sm_12x family is shown by the `.target` list in s11.1.2). Forum threads agree that tcgen05 is absent on SM121 (not NVIDIA documentation). |

Implication (INFERRED): for batch-1 decode the tensor-core instruction set barely matters. Decode is a matrix-vector product read from memory; a 4-bit format can be dequantised inside a CUDA-core GEMV and only its bytes count. FP4 `mma.sync` matters for prefill and for verifying many draft tokens.

### 2.2 Ceilings by format

Bytes read per generated token (weights only, KV negligible at short context). 30B: sizes from the actual checkpoint headers (`~/models/qwen3-30b-a3b-instruct-2507-fp8`: attention and experts are `F8_E4M3` with bf16 block scales, `lm_head` and router/norm bf16 per `modules_to_not_convert`): 48 x (8 experts x 3 x 2048 x 768 + attention 18.9 M) plus bf16 head plus bf16 routers = 3.365 GB (calc:e61e65be). 8B: 7,568,097,280 weights per token (calc:2ebb5af4, from the design note).

| Model and weight format | GB per token | Ceiling at 273 GB/s | At 212 GB/s | Where I am |
|---|---|---|---|---|
| 30B MoE FP8 (today) | 3.365 | 81.1 (calc:7844fc2e) | 63.0 (calc:43ef87a8) | 38-43 measured: 47-53% of the 273 line, 60-68% of the 212 line |
| 30B FP8 with sparse head | 2.743 | 99.5 (calc:199d0d25) | 77.3 (calc:062a5228) | not built |
| 30B NVFP4 weights, bf16 head | 2.176 (calc:bebe9ef8) | 125.5 | 97.4 | not built |
| 8B bf16 | 15.14 | 18.0 | 14.0 | old path 12.2; new engine plan 12.7-13.8 |
| 8B FP8 (official Qwen checkpoint) | about 7.6 | 36.1 | 28.0 | not built |
| 8B NVFP4 | 4.257 (calc:1683be) | 64.1 | 49.8 | not built |
| 8B bf16 with sparse head | 13.9 | 19.6 | 15.3 (calc:ee08753a) | not built |

NVFP4 bytes use 4.5 bits per weight: 4 bits plus one FP8 scale per 16 values (PROVEN `H`, NVIDIA blog "Introducing NVFP4", sections "Micro-block scaling" and "Memory"; https://developer.nvidia.com/blog/introducing-nvfp4-for-efficient-and-accurate-low-precision-inference/ ), plus a per-tensor FP32 scale.

Calibration of "how close can I get": NVIDIA's Llama 3.1 8B NVFP4 TRT-LLM number is 38.65 tok/s. Its weight-read line at 273 GB/s is 54.9 tok/s if the head stays bf16, 64.7 if everything is 4-bit (calc:4d313e42, calc:06b587ea; both INFERRED from the model's published 8.03 B parameters). So NVIDIA's own engine reaches about 60-70% of the line. My 30B at 47-53% of the same line has real headroom, but INFERRED realistic headroom is about +15-30%, not 2x, before changing formats.
The LMSYS review (secondary, not NVIDIA) measured Llama 3.1 8B FP8 at 20.5 tok/s, batch 1, SGLang, about 60% of the 34 tok/s line (`H`, https://www.lmsys.org/blog/2025-10-13-nvidia-dgx-spark ).

### 2.3 Weight formats and accuracy evidence (Qwen-class)

| Format | Evidence | Tag |
|---|---|---|
| FP8 block-128, official | Qwen publishes `Qwen3-30B-A3B-FP8` and `Qwen3-8B-FP8` ("fine-grained fp8 quantization with block size of 128"); the cards give no benchmark table. | PROVEN `H` https://huggingface.co/Qwen/Qwen3-8B-FP8 |
| FP8 W8A8 in general | "effectively lossless across all model scales"; DeepSeek-R1-Distill-Qwen family average recovery 99.0-101.0% (Table 4). | PROVEN `H` https://arxiv.org/abs/2411.02355 |
| NVFP4 on this exact model | NVIDIA's `Qwen3-30B-A3B-NVFP4` card (ModelOpt, linear layers of transformer blocks) vs baseline: MMLU-Pro 0.78 to 0.77, GPQA-Diamond 0.62 to 0.61, MATH-500 0.96 to 0.96, AIME 2024 0.75 to 0.80, LiveCodeBench 0.51 to 0.65, HLE 0.07 to 0.05. No 8B table on its card. | PROVEN `H` https://huggingface.co/nvidia/Qwen3-30B-A3B-NVFP4 (that checkpoint is the thinking-capable base, not the 2507 Instruct I run; INFERRED) |
| NVFP4 vs FP8 in general | "1% or less accuracy degradation" on DeepSeek-R1-0528 (blog Fig. 6); 12B model on 10T tokens, relative loss error below 1%; MXFP4 about 2.5% vs NVFP4 about 1.5% (8B, 1T tokens). | PROVEN `H` NVIDIA blog above; https://arxiv.org/abs/2509.25149 s3, s5 |
| Plain 4-bit PTQ on Qwen3 | Weight-only 4-bit visibly hurts Qwen3-8B MMLU: 74.7 to 69.3 (AWQ), 73.4 (GPTQ g128); 8-bit near lossless. | PROVEN `H` https://arxiv.org/abs/2505.02214 , Table 4 |
| 4-bit on reasoning models | W4A16 average drop 0.4-2.4% on R1-distill Qwen 1.5B-32B; W4A4 with MXFP4 drops of 45% (1.5B) and 59.7% (7B). | PROVEN `H` https://arxiv.org/abs/2504.04823 , Table 1 |
| FP6 | PTX lists FP6 `mma` operand types for the sm_12x family; I found no primary accuracy evidence for FP6 on Qwen-class models. | PTX PROVEN; accuracy UNKNOWN |

INFERRED guidance: (a) take the vendor's FP8 for the 8B; no own quantiser, so the "our quantisation needs its own qualification" objection in the design note does not apply. (b) For 4-bit, use NVFP4 (block 16, FP8 scale) rather than MXFP4 (block 32, power-of-two scale), keep activations at bf16 or FP8, and expect NVIDIA's calibration recipe (ModelOpt) to be the reference. Because decode is weight-bound, weight-only is enough. (c) Qualify any NVFP4 build against the FP8 golden outputs, because the one NVIDIA table above is for a different checkpoint.

### 2.4 Speculative decoding that fits batch-1, memory-bound decode

| Method | Measured | Notes | Source |
|---|---|---|---|
| Draft model (Leviathan; Chen) | 2.0-3.4x on T5-XXL, TPU-v4, batch 1 (EnDe T=0: gamma 7, alpha 0.75, 3.4x); Chinchilla 70B 2-2.5x. | Expected tokens per step = (1 - a^(g+1)) / (1 - a) (Eq 1, s3.1). The paper assumes g+1 parallel evaluations cost no extra wall time (s3.3); that is an assumption, not a measurement. PROVEN | https://arxiv.org/abs/2211.17192 ; https://arxiv.org/abs/2302.01318 (abstract only read) |
| Medusa | 2.18-2.33x (stage 1), 2.83x (stage 2) on Vicuna 7B/13B, batch 1; 5 heads recommended `H` | Trains heads, needs special recipe | https://arxiv.org/abs/2401.10774 |
| EAGLE-1/2/3 | EAGLE-1 Vicuna-7B 2.90x, LLaMA2-70B 3.01x; EAGLE-2 up to 4.26x (tau 4.83); EAGLE-3 LLaMA-3.1-8B 4.40x, tau 6.13, and on H100 batch 1 SGLang 158.34 to 373.25 tok/s (about 2.36x). Draft is one decoder layer plus a projection; training data about 68K + 464K dialogues. `H` | Gains shrink with batch; the paper's own table shows EAGLE-3 1.38x at batch 64 (SGLang) | https://arxiv.org/abs/2503.01840 Tables 1-4 (text of Tables spot-read) |
| Lookahead decoding | 1.5-2.3x on A100 batch 1 (LLaMA-2 7B-70B); needs extra FLOPs (about 120x on 7B) `H` | Wasteful when compute is scarce | https://arxiv.org/abs/2402.02057 |
| Prompt lookup | "2x-4x in input-grounded tasks"; about 2.4x average on summarisation and context QA, Mistral-7B, A100 `H` | No training, no draft model; small gains when little text is copied | https://github.com/apoorvumang/prompt-lookup-decoding |
| MoE verify cost | Verifying k drafts loads more experts: "increasing data movement and verification time by 2-3x" on Mixtral; speculation on MoE gave 39% faster on code but 54% slower on math at K=3 (RTX 6000 Ada, batch 1). `H` | The NVIDIA co-authored Cascade paper | https://arxiv.org/abs/2506.20675 abstract, s2.3, s3 |
| EAGLE-3 on Qwen3-30B-A3B, A100, single request | Speedup 1.7-1.9x, mean accepted length 2.9-3.2 across GSM8K/MATH500/HumanEval/MBPP/CNN-DM; expert budgeting (MoE-Spec) raises to 1.7-2.4x. PROVEN (Table 1 read in PDF text) | A100 has far more bandwidth than a Spark; the drafts are official EAGLE-3 adapters | https://arxiv.org/abs/2602.16052 , Table 1 (text l.304-334) |
| EAGLE-3 on Spark | LMSYS: "up to a 2x speed-up" for Llama 3.1 8B FP8 (secondary, no tok/s given). NVIDIA's own Spark playbook for EAGLE-3 could not be read (the page redirected). | UNKNOWN for NVIDIA-measured numbers | https://www.lmsys.org/blog/2025-10-13-nvidia-dgx-spark `H` |

Why the dense 8B and the 30B MoE differ (INFERRED from the table and the model configs):

- Dense 8B: verifying k tokens reads the same 15 GB of weights once. FLOPs per token are 15.1 GFLOP; at the 24.6 TFLOPS I have measured on this chip (an FP8 kernel; the bf16 figure is UNKNOWN) that is 0.62 ms, against 71 ms to read the weights at 212 GB/s, so compute equals the weight read only near 115 tokens per pass. Verify of 4-8 tokens should cost about one decode step, if a skinny multi-row GEMV exists. It does not today: the old path prefills at 6.1 ms per token (design note s1), which would make a k=4 verify cost 4 steps. The enabling work is an m-row (m up to 16) bf16/FP8 GEMV that streams the weights once.
- 30B MoE: each token picks 8 of 128 experts per layer. With independent routing, four draft tokens touch about 29 distinct experts per layer, 3.6 times the expert bytes (1 - (15/16)^4 = 0.2275 of 128; INFERRED, real routing is correlated across adjacent tokens). Experts are 1.81 GB of the 3.37 GB per token, so a 4-token verify reads about 8 GB, 2.4 times one step. With an accepted length near 3 (MoE-Spec's measured 2.9-3.2) the net is about 1.25x, in line with Cascade's 2-3x data-movement statement. Treat MoE speculation as low-yield on this chip until the 8B shows the machinery works.

Expected gain for the 8B (INFERRED): with free drafts at acceptance 0.7 per token and 4 drafts, Eq 1 gives 2.77 tokens per step (hand arithmetic from the formula); with a verify at 1.15 steps that is 2.4x. EAGLE-3-class heads report 2.0-2.4x end to end on 8B models (H100, Spark secondary), so a lookup-based scheme with Omegese-specific acceptance could match them with no training. The acceptance of lookup drafts on Omegese is UNKNOWN; it can be measured offline from saved completions (count how often the next 4 tokens are predicted by the longest match in the prompt's examples) with no GPU.

### 2.5 How a grammar mask changes speculative decoding

- PROVEN: forced tokens are speculation with 100% acceptance (llguidance fast_forward.md). SGLang's compressed finite-state machine reports 1.6x throughput on a JSON benchmark from decoding multi-token forced edges in one pass (`H`, https://arxiv.org/abs/2312.07104 , s6.3). The same paper warns forced choices can skew probabilities and need retokenisation (App B.2-B.3).
- PROVEN (`H`): DOMINO's count-based speculation reached about 1.7x on schema JSON with 6-10 drafts, little on free-form text (s4.2).
- INFERRED, no primary measurement: the mask can raise acceptance two ways. (1) Apply the automaton to the draft chain and drop draft tokens the mask forbids before verification, so no verify slot is wasted. (2) In lossless speculative sampling the accept probability for a position is the overlap sum of min(p, q) between target p and draft q (Leviathan s3); if both p and q are masked to the legal set before the comparison, probability mass on illegal tokens no longer causes rejections. I searched for a paper measuring either and found none. UNKNOWN.
- Requirement that follows: the automaton must run down the draft chain and roll back. See section 1.7 B1.

### 2.6 Levers ranked by expected tok/s gain per unit of engineering

Estimates are INFERRED from the ceilings above unless stated; none are measured on this engine.

**Dense Qwen3-8B (design ceiling 14-18 tok/s at bf16):**

| Rank | Lever | Gain | Effort | Why this rank |
|---|---|---|---|---|
| 1 | Official FP8 weights, FP8 dense GEMV (reuse the MoE FP8 GEMV work) | about 2x bytes: 14.0 to 28.0 at 212 GB/s | Medium | Biggest single factor; no quantisation research needed |
| 2 | Sparse output head (needs the Omegese mask) | +9% at bf16, about +17-20% once body weights are FP8 (INFERRED: 1.245 GB of about 7.6 GB) | Medium | Cheap once section 1.7 B1-B2 exist |
| 3 | Multi-row (m up to 16) GEMV plus grammar-forced and lookup drafts | Up to 2-2.8x on text with good acceptance (UNKNOWN acceptance) | Medium | Also the base for EAGLE later |
| 4 | One-list decode graph (dense recorder K3) | +9% (design note: 12.7 to 13.8) | Medium | Already planned |
| 5 | EAGLE-3 head trained on checker-validated Omegese | 2.0-2.4x reported on 8B elsewhere; adds to 3 only partly | High | Training pipeline, tree attention, extra kernels |
| 6 | NVFP4 weights | 4.257 GB: 3.6x fewer bytes than bf16, 1.8x fewer than FP8 | High | Own quantiser or NVIDIA's ModelOpt, new kernel, new golden outputs |

**Qwen3-30B-A3B FP8 MoE (38-43 tok/s):**

| Rank | Lever | Gain | Effort | Why this rank |
|---|---|---|---|---|
| 1 | Profile the gap to the bandwidth line (launch gaps, router, attention, host sync); NVIDIA's engines reach 55-70% of the line | +15-30% realistic | Medium | Cheapest if one big stall exists; UNKNOWN until measured |
| 2 | Sparse output head | +22.6% on the 212 GB/s line (63 to 77) if bandwidth-bound | Medium | Largest single bytes cut available without changing the weights |
| 3 | NVFP4 experts and attention (weight-only), head stays bf16 | bytes -35%; ceiling 63 to 97 at 212 GB/s | High | New grouped GEMV and quantiser; accuracy table is for the base model |
| 4 | Speculative decoding with forced and lookup drafts | about 1.25x at best for 4-token chains (INFERRED above), possibly negative on math-like text | Medium-High | MoE verify cost; do after the 8B proves the multi-row path |
| 5 | EAGLE-3 for 30B | 1.7-1.9x on A100 (MoE-Spec Table 1); expect less on Spark | High | Same cost issue |

Choice of model (INFERRED): the 30B at 40 tok/s is already 2.2x the 8B's bf16 ceiling. The 8B only wins after FP8/NVFP4 and speculation, and then its quality per task is lower. Decide on trial accuracy per second, not on tok/s alone.

---

## 3. Seeded sampling semantics in reference implementations (oracle for Stage S)

Versions read: llama.cpp fd55cb98 (2026-10-15), vLLM e8e1e961 (2026-10-15), transformers 4e3fc5e8 (2026-10-15). All PROVEN from source.

| Aspect | llama.cpp | vLLM (v1) | HF transformers |
|---|---|---|---|
| Order of operations | Default chain: penalties, DRY, top-n-sigma, **top_k**, typical, **top_p**, min_p, XTC, **temperature** last (`common/common.h:264-273`). Final stage: greedy or `dist(seed)` (`common/sampling.cpp:402-406`). | Penalties, then **temperature**, then min_p, then **top_k then top_p**, then sample (`vllm/v1/sample/sampler.py:28-56` docstring, `:230-239` temperature, `:247-302`) | **temperature**, top_k, top_p, min_p ... (`src/transformers/generation/utils.py:1579-1604`) |
| Temperature | Divides logits by T; T <= 0 keeps only the max logit (`src/llama-sampler.cpp:265-290`) | In-place divide; requests with T < 1e-5 are treated greedy (`sampler.py:230-239`, `_SAMPLING_EPS`) | Divide, skipped when T == 1.0 (`utils.py:1594-1595`) |
| top_k | Partial sort, keep k; k <= 0 disables (`llama-sampler.cpp:321-336`) | Mask below the k-th largest sorted logit (`ops/topk_topp_sampler.py:494-502`) | `TopKLogitsWarper`, k > 0 (`logits_process.py:596-606`) |
| top_p | Softmax, sort descending, keep until cumulative >= p (inclusive of the crossing token) (`llama-sampler.cpp:1555-1595`) | Sort ascending, softmax, cumsum, drop where cumulative <= 1 - p (`topk_topp_sampler.py:506-508`) | Same ascending form: drop where cumulative <= 1 - top_p (`logits_process.py:544-551`) |
| What top_p sees | Distribution at T = 1 (temperature runs last) | Distribution after temperature | Distribution after temperature |
| Draw | `std::mt19937(seed)`, one `uniform_real_distribution<double>` per token, walk the cumulative sum to `rnd x sum` (`llama-sampler.cpp:1156-1215`, init `:1405-1418`); default seed means "pick a random one" (`:340-`) | Softmax to fp32, then noise `q ~ Exponential(1)`, pick `argmax(probs / q)` (`topk_topp_sampler.py:546-575`) | `torch.multinomial(softmax(scores), 1)` (`utils.py:3250-3255`) |
| Seed | `seed` in the sampler context; stream advances once per sampled token | Per-request `torch.Generator` seeded when the request is added (`vllm/v1/worker/gpu_model_runner.py:1252-1257`); requests without a seed use the global generator | No per-call seed in `generate`; reproducibility comes from the global `torch.manual_seed` (grep of `generation/utils.py` finds no seed argument) |

Consequences for my Stage S (INFERRED):

1. My server follows the Qwen/OpenAI convention (temperature=0.7, top_p=0.8, top_k=20), which is the vLLM and HF order: temperature, then top_k, then top_p. llama.cpp's default chain applies top_p before temperature, so its output at T != 1 differs even for the same seed. Pick vLLM/HF order as the oracle and say so in the spec. The top_p keep-set is the same in the three codes up to float rounding of the cumulative sum; test the keep-set on synthetic logits with exact ties.
2. No two implementations draw the same number from the same seed (mt19937 doubles vs torch exponential noise vs torch multinomial). So bit-equal sampled text across implementations is impossible by construction. The oracle must be (a) exact on the deterministic part: given logits and parameters, the filtered and renormalised probability vector and its support equal the reference formula; (b) exact on selection: given a fixed uniform u, the chosen index equals the cumulative-walk result; (c) statistical on the draw: over N = 10,000 draws with a fixed seed per draw, the empirical histogram on a toy distribution passes a chi-square test; (d) contractual on the seed: same seed gives identical text, different seeds give different text with probability near 1 at T=0.7, and the per-step seed `decode_sampling_seed(seed, step)` differs across steps.
3. The reported symptom (identical text across seeds at T=0.7, top_p=0.8) matches two candidates: the seed never reaches `sample_with_params` on the path used by the server, or the one-list decode graph's in-graph ARGMAX is used for all requests (the design note says it is "for greedy, logits read back for sampled requests", `dgraph.rs:17-19`). Neither is established; UNKNOWN. The cheapest retiring cut is a CPU test of `sample_with_params` with two seeds on fixed logits (must differ), then the same through the server with the graph disabled.
4. Remember that on the mask path the legal-id list goes in before the filters; top_k and top_p then act on the masked logits (the order in vLLM's constrained path is mask, temperature, top_k, top_p; INFERRED from the docstring order, "allowed token ids whitelist" is step 3 of `sampler.py:28-56`).

---

## 4. Open items and what would retire them

| Item | Status | Cut that retires it |
|---|---|---|
| Fraction of Omegese positions with exactly one legal word | UNKNOWN. Exact sets exist today only after `ret`, `if`/`while` and for binary-op second operands (omegese.c:929-985). | After the automaton is exact (rec 3), replay the 30 saved completions and the 10 reference programs and count |
| Acceptance of lookup drafts on Omegese | UNKNOWN | Offline n-gram replay on saved completions; no GPU |
| Verify cost of k = 4-8 rows on my 8B kernels | UNKNOWN. Literature assumes it is about one step but does not measure it (Leviathan s3.3 assumes it; Cascade shows it fails for MoE). | Build the multi-row GEMV and time m = 1, 2, 4, 8, 16 on the chip when it is free |
| bf16 and FP8 dense TFLOPS of GB10 | UNKNOWN (NVIDIA publishes only 1 PFLOP FP4, with sparsity on one page) | Own microbenchmark, or NVIDIA datasheet if one appears |
| Why identical text across seeds | UNKNOWN, two candidates in section 3 | CPU unit test, then server test with the graph off |
| NVFP4 accuracy for Qwen3-30B-A3B-Instruct-2507 and Qwen3-8B | UNKNOWN; NVIDIA's table is for another checkpoint, the 8B card has none | Own golden-output comparison against the FP8 build |
| FP6 accuracy on Qwen-class models | UNKNOWN, no primary source found | Skip unless a paper appears |
| Type-constrained decoding gain for a brand-new language with a weak prior | Direction PROVEN for TypeScript and JSON; size for Omegese UNKNOWN | The grid in section 1.7 D |
| Whether Omegese's design is novel | UNVERIFIED (spec s8) | Not worth more effort now |
| Facts marked `H` | Read through helper summaries; digits and quotes may differ from the papers | Spot-check before quoting outside this note |

## 5. Source table

"Read" says how I got it: FT = full text read by me (PDF text, HTML or source file); P = page fetched by me; H = helper summary.

| Id | Source | URL | Read |
|---|---|---|---|
| S1 | XGrammar, Dong et al. | https://arxiv.org/abs/2411.15100 | FT (key numbers re-checked) |
| S2 | Grammar-Aligned Decoding, Park et al. (NeurIPS 2024) | https://arxiv.org/abs/2405.21047 | FT (key numbers re-checked) |
| S3 | Type-Constrained Code Generation, Mündler et al. (PLDI 2025) | https://arxiv.org/abs/2504.09246 | FT |
| S4 | SynCode | https://arxiv.org/abs/2403.01632 | H |
| S5 | DOMINO, Guiding LLMs the Right Way | https://arxiv.org/abs/2403.06988 | H |
| S6 | Outlines, Efficient Guided Generation | https://arxiv.org/abs/2307.09702 | H |
| S7 | JSONSchemaBench | https://arxiv.org/abs/2501.10868 | H |
| S8 | Let Me Speak Freely? | https://arxiv.org/abs/2408.02442 | H |
| S9 | CRANE | https://arxiv.org/abs/2502.09061 | H |
| S10 | llguidance docs (optimizations, fast_forward, toktrie) and code | https://github.com/guidance-ai/llguidance | FT (docs and code at 6cef6ed) |
| S11 | XGrammar code | https://github.com/mlc-ai/xgrammar | FT (code at 7e269d5) |
| S12 | Flexible and Efficient Grammar-Constrained Decoding | https://arxiv.org/abs/2502.05111 | abstract via search |
| S13 | Decode-Time Grammars | https://arxiv.org/abs/2607.18357 | H (abstract) |
| S14 | Grammar Prompting, Wang et al. | https://arxiv.org/abs/2305.19234 | H |
| S15 | Many-Shot In-Context Learning | https://arxiv.org/abs/2404.11018 | H |
| S16 | Kalamang grammar book in context | https://arxiv.org/abs/2409.19151 | H |
| S17 | Gleam/MoonBit new-language study | https://arxiv.org/abs/2606.16827 | H |
| S18 | Low-resource R and Racket, no silver bullet | https://arxiv.org/abs/2501.19085 | H |
| S19 | Teaching an unseen language (Zhuang) | https://arxiv.org/abs/2402.19167 | H |
| S20 | MultiPL-T | https://arxiv.org/abs/2308.09895 | H |
| S21 | SimPy, AI Coders Are Among Us | https://arxiv.org/abs/2404.16333 | H |
| S22 | How Many Tries Does It Take? (self-repair rounds) | https://arxiv.org/abs/2604.10508 | FT (Table I) |
| S23 | Teaching LLMs to Self-Debug | https://arxiv.org/abs/2304.05128 | H |
| S24 | Is Self-Repair a Silver Bullet? | https://arxiv.org/abs/2306.09896 | H |
| S25 | LLMs Cannot Self-Correct Reasoning Yet | https://arxiv.org/abs/2310.01798 | H |
| S26 | Leviathan et al., Speculative Decoding | https://arxiv.org/abs/2211.17192 | H |
| S27 | Chen et al., Speculative Sampling | https://arxiv.org/abs/2302.01318 | H (abstract) |
| S28 | EAGLE / EAGLE-2 / EAGLE-3 | https://arxiv.org/abs/2401.15077 , https://arxiv.org/abs/2406.16858 , https://arxiv.org/abs/2503.01840 | H (EAGLE-3 PDF fetched, tables not re-checked) |
| S29 | Medusa | https://arxiv.org/abs/2401.10774 | H |
| S30 | Lookahead Decoding | https://arxiv.org/abs/2402.02057 | H |
| S31 | Prompt Lookup Decoding | https://github.com/apoorvumang/prompt-lookup-decoding | H |
| S32 | Utility-Driven Speculative Decoding for MoE (Cascade) | https://arxiv.org/abs/2506.20675 | H plus text skim |
| S33 | MoE-Spec | https://arxiv.org/abs/2602.16052 | FT (Table 1) |
| S34 | SGLang (compressed FSM) | https://arxiv.org/abs/2312.07104 | H |
| S35 | NVIDIA DGX Spark hardware page | https://docs.nvidia.com/dgx/dgx-spark/hardware.html | P |
| S36 | NVIDIA DGX Spark product page | https://www.nvidia.com/en-us/products/workstations/dgx-spark/ | H |
| S37 | NVIDIA blog, DGX Spark performance (Table 4) | https://developer.nvidia.com/blog/how-nvidia-dgx-sparks-performance-enables-intensive-ai-tasks | H |
| S38 | NVIDIA blog, Introducing NVFP4 | https://developer.nvidia.com/blog/introducing-nvfp4-for-efficient-and-accurate-low-precision-inference/ | H |
| S39 | Pretraining LLMs with NVFP4 | https://arxiv.org/abs/2509.25149 | H |
| S40 | nvidia/Qwen3-30B-A3B-NVFP4 model card | https://huggingface.co/nvidia/Qwen3-30B-A3B-NVFP4 | H |
| S41 | Qwen/Qwen3-8B-FP8 and Qwen3-30B-A3B-FP8 cards | https://huggingface.co/Qwen/Qwen3-8B-FP8 | H |
| S42 | Give Me BF16 or Give Me Death | https://arxiv.org/abs/2411.02355 | H |
| S43 | Empirical Study of Qwen3 Quantization | https://arxiv.org/abs/2505.02214 | H |
| S44 | Quantization Hurts Reasoning? | https://arxiv.org/abs/2504.04823 | H |
| S45 | PTX ISA 9.4 | https://docs.nvidia.com/cuda/parallel-thread-execution/index.html | FT (grep of full page text) |
| S46 | LMSYS DGX Spark review (secondary) | https://www.lmsys.org/blog/2025-10-13-nvidia-dgx-spark | H |
| S47 | llama.cpp sampler code | https://github.com/ggml-org/llama.cpp (fd55cb98) | FT |
| S48 | vLLM v1 sampler code | https://github.com/vllm-project/vllm (e8e1e961) | FT |
| S49 | HF transformers generation code | https://github.com/huggingface/transformers (4e3fc5e8) | FT |
| S50 | Omegese spec, protocol, tool | omega-glyph `docs/one_layer/OMEGESE.md`, `EXP445_PROTOCOL.md`, `tools/omegese/omegese.c` (d1cee83) | FT |
| S51 | Own-8B design note | `~/handoffs/2026-10-15-own8b-design.md` | FT |
| S52 | Local 30B FP8 checkpoint header and config | `~/models/qwen3-30b-a3b-instruct-2507-fp8/config.json`, safetensors header | FT |
| S53 | NVIDIA developer forum threads on SM121 tcgen05 (community, not NVIDIA documentation) | https://forums.developer.nvidia.com/t/dearest-cutlass-team-when-the-hell-are-you-going-to-properly-fix-tcgen05-fp4-support-for-dgx-spark-gb10-sm121/359598 | search snippet only |
