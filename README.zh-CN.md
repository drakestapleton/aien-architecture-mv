# AIEN 架构

<!-- languages -->
[English](README.md) · **简体中文**
<!-- /languages -->

AIEN 项目如何组合在一起的权威来源：整体系统架构、里程碑状态，以及下一步要做什么。这里存放的是文档和几个小型检查工具，而不是产品代码。

AIEN 是一个主权计算栈（由其所有者端到端地构建、运行和掌控），正在一台 NVIDIA DGX Spark（Grace Blackwell GB10）上公开构建：它有自己的操作系统内核（Aienux）、自己的反应式运行时和编译器（Omega），以及自己的机器实现层（FORGE）。立项原则：离硬件最近、速度最快者胜出。缺什么就造什么。

整个系统是 Sovereign Intelligence（SI）。AienOS 只是操作系统层；Aienux 是它的内核。[aien-dev/aienix](https://github.com/aien-dev/aienix) 已退役。[sovereign-intelligence](https://github.com/aien-dev/sovereign-intelligence) 是集成、发布和安装中心，也是运行签名 Spark 测试的地方（[ADR 0045](docs/adr/0045-aienix-retired-sovereign-intelligence-center.md)）。本仓库负责保存设计决策和权威的状态记录。

**2026-10-26 状态：AienOS 处于 alpha 测试阶段；栈的其余部分处于研究级、pre-alpha 阶段。** Alpha 测试者只需安装一个软件包：由 aien-sovereign-core-mv `main` 构建的 Core 引擎、Omega 安装向导和编译器（omc），以及 CUDApp 用户态替代组件。它的 GPU 路径只能在 DGX Spark（GB10）上运行，而且三轮物理鉴定尚未执行。该软件包之外的一切，包括 Aienux 内核，都处于 pre-alpha 阶段。除非有凭证证明，AIEN 中的任何部分都不会被描述为已通过鉴定。详情如下。

**2026-10-30 注：** ADR 0045 将整个系统命名为 Sovereign Intelligence（SI）；AienOS 现在只是操作系统层。在上面 2026-10-26 的状态说明中，“AienOS”指的是整个系统。

## 人类主导的智能体工程

开发遵循人类主导的智能体工程（HDAE）：由人类定义目标、架构、约束、验收标准和停止点；智能体在这些边界内实现功能、执行检查、诊断故障并进行修改。人工评审对主张、验收和发布决策负责。现有的计划权威、里程碑登记册和鉴定要求保持不变。

关于该方法的文档说明和系统软件案例研究，参见 Gregory M. Kurtzer，*Ginux: Building an Independent Kernel That Runs Linux Userspace through Human-Directed Agentic Engineering*（2026），[doi:10.5281/zenodo.23682548](https://doi.org/10.5281/zenodo.23682548)。这是对当前开发方法的描述，并不是对历史实验或凭证的追溯性修改。

## 当前状态

上述软件包处于 alpha 测试阶段；其余一切处于研究级、pre-alpha 阶段。实时数字每天都在变化，因此不在本文件中重复；请阅读 [CURRENT_EXECUTION_PLAN.md](CURRENT_EXECUTION_PLAN.md) 和 [doctrine/ROADMAP.md](doctrine/ROADMAP.md)。以下是摘要，并给出每一点的来源。

- **Aienux 内核。** 这个 C 内核通过了模拟器（QEMU）门禁，但尚未通过物理鉴定，也还没有在 DGX Spark 上启动过。此前只有上一代 Rust 内核的一次早期首次启动测试在那里运行过，时间是 2026-09-24（参见 [Aienux README](https://github.com/aien-dev/aienux#readme)）。它首次在真实硬件上运行是在 2026-10-13，平台为 Raspberry Pi 5（同一 README）。它的 x86_64 构建可以在一台用作测试计算机的 2017 年款 Intel iMac 上启动（[aienux#405](https://github.com/aien-dev/aienux/pull/405)，2026-10-17 合并，以及后续拉取请求 #406 至 #408）。Aienux README 尚未描述在 iMac 上的运行。
- **Omega 运行时，R1 至 R16 阶梯。** 这一阶梯最初是在一些构建上通过鉴定的，而这些构建早于当前活态构建中的组合模块。在 omega `3108fc2` 上的重新鉴定记录为 R15 FAIL（16 项门禁中通过 14 项）和 R16 FAIL（omega [`evidence/REQUAL-3108fc2/`](https://github.com/aien-dev/omega-mv/tree/main/evidence/REQUAL-3108fc2)）。该阶梯随后在候选版本 CAND-3（omega `f816473`）上重新运行：R16 的 G1 至 G8 门禁 PASS；R15 通过了 16 项门禁中的 16 项，但只算有条件通过，因为那次运行关闭了 Secure Boot（[CAND-3 结果](qualification/candidates/CAND-3.gates.md)、[例外 0002](qualification/exceptions/0002-r15-secure-boot-off.md)）。并不主张 CAND-3 整体已通过鉴定，而 CAND-4 没有重新运行 R15 或 R16（[CAND-4 结果](qualification/candidates/CAND-4.gates.md)）。[doctrine/ROADMAP.md](doctrine/ROADMAP.md) 中的 R15 和 R16 行仍沿用早先的措辞（停留在 CAND-0 和 CAND-1）。
- **ARGUS**（防御平面，负责监视攻击并提出响应建议，但从不授权执行这些响应）。其事件基底 ARGUS-0 已在文档记录的限制范围内完成，ARGUS-1 遏制功能正在开发中（[ADR 0017](docs/adr/0017-argus-defensive-plane.md)）。
- **仅有规范。** Physics Zero、DIRAC-0、演化竞技场和必要工作计划都只是文档或计划，没有经过鉴定的代码（参见下文的[规范与计划](#specifications-and-plans-not-qualified-code)）。

## 从这里开始

按以下顺序阅读：

1. [计划权威](PLAN_AUTHORITY.md)：哪份文档优先
2. [当前执行计划](CURRENT_EXECUTION_PLAN.md)：唯一现行的跨项目计划，附凭证
3. [规范架构](doctrine/ARCHITECTURE.md)：系统是什么，以及谁负责什么
4. [规范里程碑登记册](doctrine/ROADMAP.md)：里程碑 ID 与状态
5. [架构决策记录](docs/adr/README.md)
6. [实现状态快照](docs/02-implementation-status.md)和[仓库地图](docs/01-github-repository-map.md)
7. [黄金路径](docs/13-golden-path.md)
8. [种子谱系](docs/SEED_LINEAGE.md)：每个正在运行的产物、目前由什么构建它，以及种子链的哪一级能够孕育出它

被取代的计划只保存在 [docs/archive/plans](docs/archive/plans/README.md) 下。如果两份文档有分歧，不要再写一份总体计划：记录分歧，并修正权威文档。代码和可复现的证据胜过任何计划。

## 本仓库包含什么

| 路径 | 内容 |
| :--- | :--- |
| `PLAN_AUTHORITY.md`、`CURRENT_EXECUTION_PLAN.md` | 哪份计划优先，以及唯一的现行计划 |
| `doctrine/` | 规范架构和里程碑登记册 |
| `docs/adr/` | 架构决策记录（`main` 上共 45 份，列在[索引](docs/adr/README.md)中） |
| `docs/plans/` | 有限期的工作流计划（不是总体计划） |
| `docs/research/` | 研究笔记，例如[仓库布局笔记](docs/research/repo-topology-unix-vs-monorepo-vs-hybrid.md)和 [Hermes Agent 笔记](docs/research/hermes-agent-prior-art.md) |
| [Aienet 合作者名录](docs/research/aienet-collaborators.md) | 潜在的学术和社区联系人、来源、合作问题，以及 SI 智能体的外联规则；这不是隶属关系或注册名单 |
| `docs/archive/` | 被取代的计划，仅作历史保存 |
| `qualification/` | 发布候选版本（`candidates/CAND-*.toml` 及其门禁结果）和已记录的例外 |
| `formal/invariants/` | 为形式化检查而写下的不变量（[ADR 0027](docs/adr/0027-formal-oracle-lean-bootstrap.md)） |
| `docs/capability-register/` | 全组织范围的 CUDA 能力登记册：[register.tsv](docs/capability-register/register.tsv)（事实来源；为 CUDA 替代映射的 47 行中的每一行记录负责人、提交、架构、级别和证据文件）及其生成视图 [REGISTER.md](docs/capability-register/REGISTER.md) |
| `tools/capreg/` | 用种子自举 `.om` 编写的登记册检查器和渲染器，及其门禁（步骤 `capreg`） |
| `tools/crumb/` | 碎屑工具（C11），用于编译和检查 `.crumb` 文件 |
| `tools/ops/` | Spark 的共享测量基础设施：只构建一次，一次只开一个测量窗口，按窗口校准，以及 27B 基线（[使用方法](docs/ops/MEASUREMENT_WINDOWS.md)） |
| `scripts/` | 小型 shell 工具（准则检查、候选版本和固定版本检查、R16 状态措辞、拉取请求门禁、碎屑变基辅助工具）及其 `test_*.sh` 测试 |
| `tests/gates/` | Spark 在每个拉取请求上运行的门禁清单 |

根目录下的 `AIEN_COMPLETE_SYSTEM_ARCHITECTURE.md` 和 `AIEN_MASTER_ARCHITECTURAL_PLAN.md` 是已被取代的指针文件；旧版本位于 `docs/archive/plans/`。第二个文件在 Git 中以符号链接的形式存储，其目标就是指针文本，因此无法作为普通文件打开；请改为阅读 [docs/archive/plans](docs/archive/plans/README.md)。

## 各仓库如何协同

```text
ATLAS AWAKENS.  ALLEN INTENDS.  AIEN PROPOSES.  OMEGA DEFINES.  FORGE REALIZES.
AEGIS VERIFIES.  HARDWARE ACTS.  EVIDENCE TEACHES.
```

| 仓库 | 角色 |
| :--- | :--- |
| [aienux](https://github.com/aien-dev/aienux) | Aienux，AienOS 的内核，计划在 DGX Spark 上取代 Linux 内核 |
| [omega-mv](https://github.com/aien-dev/omega-mv) | 定义计算的 C 反应式运行时和编译器，以及原生 GB10 GPU 引擎 |
| [physics-mv](https://github.com/aien-dev/physics-mv) | FORGE 机器实现，以及历史上的 Atlas/PHYSICS 启动证据 |
| [aien-protocols-mv](https://github.com/aien-dev/aien-protocols-mv) | 带版本的线路格式与状态规范 |
| [aien-sovereign-core-mv](https://github.com/aien-dev/aien-sovereign-core-mv) | Linux 上的 Rust 主机运行时（`aien` 命令行、推理 ABI、KV 缓存、调度器），以及评判每个仓库的验证流水线；这里的 Rust 是脚手架，Omega 会逐步替换它（ADR 0024） |
| aien-architecture-mv（本仓库） | 架构、决策记录、里程碑状态和执行计划 |

这六个仓库各自维护自己的部分，仍然分别存放在独立的仓库中。[sovereign-intelligence](https://github.com/aien-dev/sovereign-intelligence) 是集成、发布和安装中心，也是运行签名 Spark 测试的地方；[aien-dev/aienix](https://github.com/aien-dev/aienix) 已退役（[ADR 0045](docs/adr/0045-aienix-retired-sovereign-intelligence-center.md)）。关于布局的研究笔记位于 [docs/research](docs/research/repo-topology-unix-vs-monorepo-vs-hybrid.md)。所有这些仓库的签名测试结果都发布到 [aien-receipts](https://github.com/aien-dev/aien-receipts)。历史上的 `PHYSICS_*` 里程碑名称在旧里程碑和证据中保持不变。较早的文档链接到 `aien-spark/<name>` 或 `aien-dev/<name>`；这些地址指的是同一批仓库的旧名称。

## 常设规则

- 语言规则：Rust 是脚手架，Omega 是目标，C 只用于有硬件理由的地方（[ADR 0024](docs/adr/0024-rust-scaffolding-omega-destination.md)，它取代了旧的 [Rust 到 C 计划](docs/plans/RUST_TO_C_MIGRATION.md)）。
- 不用 Python，不用 CUDA 工具包，不用 systemd，可信基础中没有外部依赖，离线构建。
- 判定用词：PASS、FAIL、NOT_RUN、BLOCKED_HARDWARE、BLOCKED_OPERATOR、MISSING_IMPLEMENTATION。模拟器、主机模拟和文档永远不算作硬件鉴定。

<a id="specifications-and-plans-not-qualified-code"></a>
## 规范与计划（未经鉴定的代码）

[Physics Zero Atlas](docs/plans/physics-zero/PHYSICS_ZERO_LAW_ATLAS_V1.md)、[DIRAC-0](docs/adr/0023-dirac-0-program.md) 和[演化竞技场规范 V1](docs/specs/EVOLUTION_ARENA_SPEC_V1.md) 都是文档。`docs/plans/` 下的有限期工作流计划必须标注 NOT A MASTER PLAN（[PLAN_AUTHORITY.md](PLAN_AUTHORITY.md)）；大多数已经标注，但 `physics-zero` 和 `adaptive-intelligence` 文件夹还没有带上这一标记。

[必要工作计划](docs/plans/necessary-work/README.md)（2026-10-18，PROPOSED）探讨的是：在让芯片变得更快之前，哪些工作是不必要的；其可行性研究见 [docs/research/necessary-work-program-feasibility.md](docs/research/necessary-work-program-feasibility.md)。它的实验一个都还没有运行。

## 构建与测试

这里没有要构建的产品。唯一的程序是 `tools/crumb` 中的碎屑工具。它只需要一个 C11 编译器和 `make`。构建它并运行其测试：

```sh
make -C tools/crumb test
```

碎屑已从现行工作流中退役（DRA-97，2026-11-07）：不再有门禁检查 `.crumb` 文件是否为最新，它们作为历史保留。如果你想查看，`./tools/crumb/crumb verify .` 仍然可用。

Spark 会在每个拉取请求上运行这些门禁。`tests/gates/` 中的每个清单都以一个步骤词调用 `tests/gates/run.sh`，因此你可以自己运行相同的步骤（该脚本需要 `bash`；普通的 `sh` 会在 `set -o pipefail` 处停止）：

```sh
bash tests/gates/run.sh crumb-tool-test       # gate ARCH-CRUMB-TOOL-TEST: the crumb tool tests
bash tests/gates/run.sh script-tests          # gate ARCH-SCRIPT-TESTS: tests of the four checked scripts
AIEN_OMC=<pinned omc> bash tests/gates/run.sh doctrine   # gate ARCH-DOCTRINE: doctrine consistency (tools/doctrine, seeded .om; NOT_RUN without the pinned compiler)
bash tests/gates/run.sh qualification-status  # gate ARCH-QUALIFICATION-STATUS: R16 status wording
```

`qualification-status` 会读取 omega 证据，因此需要在本仓库旁边的 `../omega` 处有一个 omega 检出副本。

对于 Cargo 仓库，`CRUMB="$PWD/tools/crumb/crumb" bash scripts/pipeline-proofs/18-crumb-only-no-rebuild.sh <repo>` 用来检查只改动 `.crumb` 的提交不会重新构建 crate。它使用位于 `${XDG_CACHE_HOME:-$HOME/.cache}/aien/pipeline/target-cold` 的持久目标缓存，该缓存位于临时克隆之外；设置 `TARGET_DIR` 可以复用另一个缓存。该证明永远不会删除这个缓存。`CARGO_ARGS` 默认为 `--locked --offline`。

## 拉取请求如何评判

自 2026-10-24 合并策略变更以来，在拉取请求和 `main` 上运行的 GitHub 托管 **AIEN Checks** 仅供参考：对于已登记的仓库，它们运行可移植的冒烟门禁（其中的 crumb verify 步骤已退役，DRA-97）。它们不会下载签名的 Spark 软件包，也不会把关合并。**AIEN Alpha** 作业只在 `alpha/*` 标签上运行，要求 `main` 上某个带标签的提交具有签名的完整 Spark 软件包。当前流程和较早的流程参见 [docs/PIPELINE.md](docs/PIPELINE.md)。

`main` 上的碎屑工具现在可以按需计算每个 `.crumb` 文件中的生成部分，而不必将其存储下来（RFC-0003 第 1 号修订，拉取请求 #271，2026-10-18 合并；[docs/CRUMB_PROTOCOL_RFC_0003.md](docs/CRUMB_PROTOCOL_RFC_0003.md)）。本仓库于 2026-10-19 切换到这一方式（拉取请求 #272）：它的 `.crumb` 文件不再存储这些数据，`crumb verify .` 会在检查时计算它们。

## 证据存放位置

- 发布候选版本及其门禁结果：[qualification/candidates](qualification/candidates) 和 [qualification/exceptions](qualification/exceptions)。
- 运行的凭证：存放在执行这些运行的仓库中，主要是 omega [`evidence/`](https://github.com/aien-dev/omega-mv/tree/main/evidence)，并由 [CURRENT_EXECUTION_PLAN.md](CURRENT_EXECUTION_PLAN.md) 和 [doctrine/ROADMAP.md](doctrine/ROADMAP.md) 引用。
- 签名的 Spark 软件包（如已生成）：[aien-receipts](https://github.com/aien-dev/aien-receipts)。普通 PR 上缺少这些软件包并不算托管检查失败。

## 参与贡献

针对 `main` 提交仅涉及文档的修改或准则修改的拉取请求，引用你所依据的凭证或代码，并说明你获得的任何外部评审。托管的 PR 检查仅供参考，既不等同于签名的 Spark 鉴定，也不代表允许合并；未经维护者批准，不要添加 `ready-to-merge` 标签。欢迎以 issue 的形式提出问题和设计想法。参见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可

采用 GNU Affero 通用公共许可证 v3.0 或更高版本（AGPL-3.0-or-later）授权。参见 [LICENSE](LICENSE) 和 [LICENSE-NOTICE.md](LICENSE-NOTICE.md)。联系方式：aien@aienos.com。
