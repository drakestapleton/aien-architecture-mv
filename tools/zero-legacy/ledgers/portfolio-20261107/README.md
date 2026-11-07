# Portfolio source, ELF and process closure snapshot, 2026-11-07 (DRA-178)

Observed 2026-11-07 on the DGX Spark host (Linux AArch64) with omc `734f0a39` (this tool's
`omega.pin`): `closure` sha256 `19aa7bd8…752a`, `elfclose` `9026b0e8…0f44e`. This is a dated
inventory, not a qualification and not a migration verdict. It replaces nothing in #300 or in
`../aien-serve-http-bin-19173f9e.tsv`; those records stay as they were.

## What was scanned

| Set | Repositories | How |
| --- | --- | --- |
| aien-dev public, not forks | 79 (63 active, 16 archived) | `portfolio.sh list.tsv OUT ZLBUILD`: each at the default-branch head in `list.tsv`, depth-1 fetch, `closure` (transitional mode) over every tracked file, `elfclose elf` over every file closure calls `ELF` |
| aien-dev public forks | 11 | not scanned: upstream code, not first-party (`forks.tsv`) |
| aien-dev private | 17 | scanned the same way on the host; results are not published here (private names and contents stay out of public files) |

79 + 11 + 17 = 107, the DRA-161 repository count. `summary.tsv` has one row per scanned public
repository: commit, archived flag, the closure count of every category, `OUTSTANDING` and `UNKNOWN`
as closure defines them, and the elfclose verdict counts of committed ELF files.
`elf-committed.tsv` is every committed ELF file with its elfclose row.

Reproducibility: a second, independent run of `portfolio.sh` over six of the repositories
(CUDApp, aien-sovereign-core-mv, physics-mv, atlas, spark-connector, aien-architecture-mv) into a
fresh directory gave byte-identical summary rows, sorted-identical closure rows and identical
elfclose rows. The full 79-repository run took one pass; it was not repeated.

## Totals (public, scanned)

| | Repos | Files | OM | C_H | RUST | PYTHON | SHELL | OSC | HEXASM | MAKE | HIDDEN | WRAPPER | FOREIGN | OUTSTANDING | UNKNOWN |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| active | 63 | 69,453 | 3,473 | 2,573 | 3,244 | 808 | 1,441 | 490 | 137 | 157 | 218 | 36 | 195 | 9,299 | 27,406 |
| archived | 16 | 842 | 0 | 49 | 71 | 157 | 3 | 0 | 0 | 2 | 30 | 0 | 10 | 322 | 212 |

`UNKNOWN` is mostly `OTHER` (26,958 active files with a suffix closure has no rule for, much of it
evidence data) plus committed ELF and archive files that no manifest declares. Without per-repository
manifests these are open rows, not zero; writing the manifests belongs to each repository's owner.
File counts are per tracked file, so they say nothing about how much of that code is built,
shipped or run.

## Owners: reconciling the #300 ledger with this snapshot (`owners.tsv`)

#300 (2026-10-23/24) bound migration work to 18 owner issues across 15 public repositories here
(plus omega-programs, private, and drakestapleton.com in aien-spark, outside this set). Against the
63 active scanned repositories:

| Group | Repos | OUTSTANDING rows |
| --- | ---: | ---: |
| has a #300 owner issue | 15 | 8,054 |
| outstanding rows but no #300 leaf (`UNCOVERED`) | 43 | 1,245 |
| no outstanding rows | 5 | 0 |

So 8,054 of 9,299 active outstanding rows (86.61 %) sit in repositories that #300 already routes;
the 43 uncovered repositories are listed in `owners.tsv`, largest first: omega-rosetta 225,
synapse 170, omega-bridge 169, openaccel-lab 105, aien-train 101, omega-gpu-driver 73,
sovereign-intelligence 42, omnet 42, gpu-head-to-head 42. Per DRA-178 a new leaf is created only
for a verified uncovered gap; this table is the input for that decision, not the decision. Some of
these rows are tests, oracles or interop shims that may be legitimate exceptions; classifying them
(owner, exact consumer, successor or reviewed exception) is the next step, per repository.

#300's preliminary indicators are kept as written; the same repositories now read:

| Repository | #300 (2026-10-24, its own filter excluding docs/evidence/research/goldens) | This snapshot (whole tracked tree) |
| --- | --- | --- |
| omega-mv | `a0eafa39`: 603 .c, 312 .h, 250 .osc, 2 .hex, 2 .hex1 | `943d9555`: C_H 1,242, OSC 480, HEXASM 47, OM 1,358 |
| CUDApp | `3f9c154c`: 108 .c, 70 .h, 8 .osc, 42 .om | `b774723f`: C_H 443, OSC 8, OM 245 |
| aien-sovereign-core-mv | `9699d928`: 714 .rs | `dffdbd19`: RUST 809, C_H 8, OM 17 |
| aienux | `5550b70f`: 260 .c, 133 .h, 191 .rs | `2fc62070`: C_H 591, RUST 1,693, OM 234 |

The two columns use different filters and different commits, so a difference is not a measured
migration change in either direction.

## Shipped ELF identity (`si-alpha-20261026.2.tsv`)

The published SI release `alpha-20261026.2` (tarball checked against its `SHA256SUMS`):
`bin/aienos` (`e4cdd917…`) is `UNMARKED`, static, PT_LOAD only, as seeded omc output is;
`bin/aien-serve-http` (`19173f9e…`, the engine of `../aien-serve-http-bin-19173f9e.tsv`) is
`FOREIGN`: dynamic, `libm.so.6, libgcc_s.so.1, libc.so.6, ld-linux-aarch64.so.1`, marks
`gcc+clang+rustc+gnu+crt+note`. The shipped engine is a Rust/C build linked against the host C
library; its migration owner is aien-sovereign-core-mv#753.

Committed binaries in active trees outside evidence directories that elfclose calls `FOREIGN`:
omega-mv `tools/physics0/pd1-convert/pd1_convert` and physics-mv `nvrm/lifecycle_gates`
(both gcc-built, dynamic). The rest are evidence blobs (omega-mv `evidence/`), AMD code objects
in CUDApp evidence, and this tool's own hostile fixtures.

## Running processes (`process-spark.tsv`)

`procsnap.sh` at 2026-11-07T03:42Z: 686 processes; 416 belong to other users and read as
`UNREADABLE` to an unprivileged scanner (NOT_RUN for them: root or per-user scans are needed);
of the scanning account's 270, 221 are `FOREIGN` (shells, Python, Node, agent tools, Rust and C
builds), 33 `UNMARKED` (omc-built: omega-mcp, ollm, omega-node, omega-tool-model servers and this
scanner) and 16 unreadable (other namespaces). The `EXE` rows list the account's executables
outside the OS and agent-tool directories with the sha256 of the running image. A process row
identifies the bytes running; tying them to a source commit needs a rebuild or a receipt.

## Not run here

- Root and other-user process scans; containers' and other machines' processes.
- Linked-object membership inside an ELF (which archive members or crates are in it).
- Source binding of `UNMARKED` binaries (rebuild-and-compare).
- Per-repository manifests declaring data, generated and external files.
- The classification of each outstanding row with owner, exact consumer and successor or reviewed
  exception (DRA-178 acceptance 1); deletions (acceptance 3, DRA-155).
