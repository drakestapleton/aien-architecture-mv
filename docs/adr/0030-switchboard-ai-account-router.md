# ADR 0030: Switchboard, one typed router over my own AI accounts

**Status:** PROPOSED, 2026-10-03. Not yet reviewed by the operator, Drake Stapleton.
**Number:** 0030 was the next free number on 2026-10-03; no open PR claimed it.
**Related:** ADR 0024 (Rust is scaffolding, Omega is destination; Decision 1 and 4 cover a new Rust crate), ADR 0028 (AIEN-TEST), ADR 0006 (production secrets are vault-only), ADR 0022 (cognitive-routing idea reused as a pattern only, no dependency).
**Evidence:** `~/mindmap/notes/2026-10-03-switchboard-research.md`, `~/handoffs/switchboard/program-facts.md`.
**Implementation:** `aien-spark/aien-sovereign-core`, `crates/aien-switchboard` (cut 3, pure types and router with a fake runner).

## Context
The operator holds subscription accounts with several AI companies: 2 Anthropic, 2 Google, 1 xAI (Grok), 1 OpenAI, plus an OpenRouter key. Today he and the hive switch between them by hand and run into usage limits. He wants one local program that decides which account handles which job, and fails over when an account is out of room.

## Decision
1. **Purpose.** A Rust crate `aien-switchboard` that owns: account list, job description, usage gauge per account, a routing rule table the operator edits, and one deterministic decision function. Commands: `switchboard run "<prompt>" [--kind code|review|research]` and `switchboard status`.
2. **Home.** New crate `crates/aien-switchboard` in `aien-spark/aien-sovereign-core`. Reason: that repo is the Linux user-space Rust scaffolding home (ADR 0024 classification A, item 19), already holds the hive, adapters, `aien-test` runner and `aien-proof`, and ADR 0024 says new non-hardware systems work defaults to Rust. Not omega (C, resident runtime, chip work), not aienos (kernel). Contract at the boundary stays language-neutral per ADR 0024 Decision 5 so Omega can replace it later.
3. **Hard design rules.**
   1. Never read, copy, store or proxy subscription login tokens (Anthropic and Google forbid it in writing; Google names account termination).
   2. Each subscription account is the company's own unmodified program (`claude`, `codex`, `agy`, `grok`), signed in by the operator through that company's own login, one settings folder per account.
   3. OpenRouter is a direct web request; the key lives in process memory, resolved from `atlas-vault`, never written to a file (ADR 0006).
   4. AIEN works fully offline. The local model is the default route; outside accounts are optional help.
   5. No Python anywhere. Rust, licensed as the workspace is (`Apache-2.0 WITH LLVM-exception`), tests run through AIEN-TEST (ADR 0028).
4. **Accounts (initial).** anthropic-1, anthropic-2 (`claude`), google-1, google-2 (`agy`), xai-1 (`grok`), openai-1 (`codex`), openrouter-1 (HTTP), plus `local` (own model, always first for jobs it can meet).
5. **Router decision.** Typed and deterministic: inputs `Job{kind,size,needs}`, per-account `Gauge{used_pct?, resets_at?, cooled_down_until?}`, and an operator-owned plain config file mapping job kind to an ordered account list. Choice = first account in the list that meets the job's needs and has room; cheapest first, in the spirit of cognitive routing. No learned model in v1. A Jev-like fast learned chooser is a later, separately gated step.
6. **Gauges.** Read where a program reports them (Claude status-line `rate_limits`; OpenRouter `GET /api/v1/key`). Where it does not, treat a limit error or failed exit as the signal and cool the account down until the reset time, else a configured default.
7. **Offline-first.** With no network the router returns `local` or a typed refusal; it never blocks waiting for a vendor.
8. **Tests.** Router and failover with fake runners (no real accounts). One live smoke per account only with the operator present to sign in.

5a. **Cut 3 choices (the crate, first slice).** The rule file also lists accounts (a settings-folder path or a key reference name, never a secret). `local` is appended as the last fallback of every route and is never skipped, so a decision always exists. The `needs` part of a job is left out for now because no first-party source says what each program can do; it is UNKNOWN and tracked for a later cut.

## Not decided here
Wiring the hive and AIEN-TEST to call the Switchboard (later ADR). Any Omega port.

## Amendment A (PROPOSED, 2026-10-16): Anthropic provider policy matrix
**Status:** PROPOSED. Needs the operator's approval before any feature that depends on it ships. Tracking: aien-architecture#236 (parent), aien-sovereign-core#592 (phase 1).

**Sources, all fetched 2026-10-16:**
- [S1] https://code.claude.com/docs/en/authentication ("Log in with multiple accounts", "Authentication precedence", "Generate a long-lived token")
- [S2] https://code.claude.com/docs/en/legal-and-compliance ("Usage policy")
- [S3] https://www.anthropic.com/legal/consumer-terms (effective 2025-10-08), section 2 and section 3
- [S4] https://www.anthropic.com/legal/aup (page states effective 2026-11-12), "Do Not Abuse Our Platform"

**Key lines:**
- S1: "To stay signed in to multiple accounts at once, such as work and personal accounts, give each account its own configuration directory."
- S1: precedence is cloud-provider variables, then `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY` ("In non-interactive mode (`-p`), the key is always used when present"), `apiKeyHelper`, `CLAUDE_CODE_OAUTH_TOKEN`, Anthropic profile or federation credentials, and last the `/login` subscription.
- S2: "Advertised usage limits for Pro and Max plans assume ordinary, individual usage of Claude Code and the Agent SDK."
- S2: "developers may not collect, store, or intermediate Claude.ai credentials or session tokens"; it does not "prevent an end user from signing in to the unmodified Claude Code binary with their own Claude subscription".
- S3: forbids access "through automated or non-human means" "Except when you are accessing our Services via an Anthropic API Key or where we otherwise explicitly permit it"; forbids "bypassing any of our systems or protective measures"; forbids sharing account login.
- S4: forbids "create multiple accounts, to avoid detection", "Circumvent a ban through the use of a different account", and "Intentionally bypass or interfere with capabilities, restrictions, or guardrails established within our products".
- S1 documents `claude setup-token` "for CI pipelines, scripts, or other environments where interactive browser login isn't available", which is an explicit permission for scripted use of the operator's own subscription.

**Matrix:**
| Execution mode | Verdict | Condition or reason |
|---|---|---|
| Operator opens the unmodified `claude` in a chosen profile folder (`CLAUDE_CONFIG_DIR`) and signs in himself | ALLOWED | Documented in S1. Switchboard sets the folder itself and never passes an inherited one. |
| Scripted `claude -p` by the operator's own tooling on his own subscription, credentials kept by `claude` in the profile folder | ALLOWED WITH CONDITIONS | Personal use only, unmodified binary, nobody else's requests (S2). Explicitly permitted scripted use per S1. |
| `claude setup-token` token handed to Switchboard | FORBIDDEN in Switchboard | Switchboard would store or pass a session token (S2 "intermediate"). The operator may still use it outside Switchboard. |
| Agent SDK or other program using subscription login | FORBIDDEN | S2 directs developers using the Agent SDK to API keys. |
| Anthropic API key (Console, pay as you go) | ALLOWED | Billed separately. Must be an explicit operator choice per profile, never picked up by accident from the environment. |
| Switchboard reads, copies, exports or proxies any credential file or token | FORBIDDEN | S2. Doctor checks only that the credentials file exists, never its contents. |
| Automatic routing (failover or load balancing) from one Anthropic subscription to another of the same operator | FORBIDDEN | Most direct reading of S4 "bypass ... restrictions" and S3 "bypassing ... protective measures": one person's work spread by a program across subscriptions to exceed one plan's limit. Operator decision 2026-10-16: excluded. The rule table rejects any route holding two subscription accounts of the same provider. Lifted only by written permission from Anthropic, recorded here. |
| Automatic failover and load balancing across different providers (Anthropic, OpenAI, Google, xAI, OpenRouter) and `local` | ALLOWED WITH CONDITIONS | Operator decision 2026-10-16: kept. Each provider's limit is honoured on its own account. Each non-Anthropic provider's terms on automated use must be read and recorded before its account joins an automatic route. |
| Operator holds more than one paid Anthropic subscription and picks one by hand per session | GREY ZONE, operator decision | S3 and S4 are silent on holding several accounts. Risk: spreading one person's usage across subscriptions to go past "ordinary, individual usage" (S2) can be read as bypassing a usage restriction (S4). Manual choice lowers but does not remove that risk. Switchboard may show which profile has the most room; the operator picks. |
| Sanctioned ways to get more room: higher plan, Team or Enterprise plan, API key | ALLOWED | The honest alternative to several subscriptions. |
| Using Claude output to train AIEN models | FORBIDDEN | S3 section 3 item 2. |

**Environment allowlist (phase 1 design rule).** Before launching `claude`, Switchboard removes every credential-selecting variable in S1's precedence list (`ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_PROFILE`, `ANTHROPIC_FEDERATION_RULE_ID`, `ANTHROPIC_ORGANIZATION_ID`, `CLAUDE_CODE_USE_BEDROCK`, `CLAUDE_CODE_USE_VERTEX`, `CLAUDE_CODE_USE_FOUNDRY`), `ANTHROPIC_BASE_URL`, and cloud-provider credential variables. Proxy variables pass only when listed in local config. `switchboard doctor` warns when an `apiKeyHelper` or `env` block in the profile's or the repository's Claude settings could bring an API key back in.

**Still UNKNOWN:** whether Anthropic support would confirm in writing that one person may hold and hand-select several paid subscriptions; the operator may ask them before relying on it.

## Open UNKNOWNs
- Anthropic consumer terms on one person holding two paid accounts to spread usage: read 2026-10-16, see Amendment A. Terms are silent on holding several accounts; spreading usage to exceed limits is the grey zone recorded there.
- xAI terms on automated use: page returned 403, not read.
- Side-by-side logins: `CLAUDE_CONFIG_DIR` documented; `CODEX_HOME` documented but multi-account not described; `GROK_HOME` name seen only in the binary; `agy` unknown.
- Usage-left in machine-readable form for codex, agy, grok: none found. Limit-error text for codex, agy, grok, and Claude's exact shape in `-p` json: undocumented.
