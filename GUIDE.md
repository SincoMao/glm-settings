# GLM-5.2 × Claude Code（Windows）配置与作业手册

> **定位**：本手册面向两个生产场景——**① BMC 级超大复杂代码体系开发**（从嵌入式底层到上层 Web 的全栈工程）与 **② A 股市场持续深度行情分析**（数据值绝对可靠、考虑问题全面、可长期稳定复跑）。
>
> **总原则**：成本与速度不纳入决策考量。所有决策仅对三项指标负责：**正确性、完备性、可靠性**。凡"节省 token / 节省配额 / 提升速度"与"更准确 / 更完整 / 更稳定"相冲突之处，一律选择后者。全链路仅允许一个模型：**GLM-5.2**——包括后台辅助任务在内，不存在任何降级路径。
>
> **适用环境**：Windows 原生 Claude Code CLI（2026-07 时点 v2.1.x）+ Z.AI GLM Coding Plan MAX（多账号轮换）。
> **文档快照日期**：2026-07-19。全部机制性结论以两个官方文档站为准：[Claude Code Docs](https://code.claude.com/docs/en/overview)、[Z.AI Docs](https://docs.z.ai)；两大领域的作业规程（第 9、10 章）为专家经验层，独立于上述文档。

---

## 目录

- **第一部分：需求定调**
  - 1. 场景需求规格（由两大场景反推的硬性需求）
  - 2. 对"高缓存命中"的定调
  - 3. 模型策略：全链路单旗舰
  - 4. 需求 → 配置追溯矩阵
- **第二部分：配置**
  - 5. 工作原理速览
  - 6. 配置文件位置、生效时机与验证
  - 7. 参数逐项详解（附权威来源）
  - 8. 有意不设置的参数及原因
- **第三部分：作业手册**
  - 9. 场景 ①：BMC 级超大代码体系开发（含 CLAUDE.md 模板）
  - 10. 场景 ②：A 股深度行情分析（含数据铁律与 CLAUDE.md 模板）
- **第四部分：运维**
  - 11. Coding Plan 专属 MCP 部署
  - 12. 多账号轮换（可用性机制，而非节省手段）
  - 13. 升级 SOP
  - 14. 一致性管理：任务中途的行为漂移源清单
  - 15. 部署后验证清单
  - 16. 故障排查速查表
- **第五部分：附录**
  - 17. 版本门槛备查表
  - 18. 参考链接汇总

---

# 第一部分：需求定调

## 1. 场景需求规格

最深思考、最完整上下文、最少截断、最高缓存命中是方向性目标，并非可直接执行的需求。本章将两个场景分解为**可验证、可映射到配置项**的需求条目（编号 A1–A6 / B1–B6，第 4 章给出每条需求到具体参数的追溯）。

### 1.1 场景 ①：超大复杂代码体系（以 BMC 为例）

BMC（基板管理控制器）开发是"单任务跨越整个技术栈"的典型代表：Yocto/bitbake 构建体系、u-boot、内核驱动（I2C/IPMB/KCS/MCTP）、设备树、D-Bus 服务群（OpenBMC 的 phosphor-* 仓库族）、IPMI / Redfish（DMTF DSP0266）协议服务、直至 WebUI 前端。由此反推的硬需求：

| 编号 | 需求 | 判定标准 |
| --- | --- | --- |
| **A1 跨栈上下文** | 单个任务的推理必须同时容纳多仓库、多语言（C / C++ / DTS / Python / JS）的真实代码与工程约定 | 1M 窗口全程可用；多目录挂载时各仓库的 CLAUDE.md 全部载入；巨型源码树的检索不超时 |
| **A2 长周期执行不中断** | 小时级构建、跨多轮的多阶段迁移中，任何一环的超时/断流/限流都不得终结任务 | 请求超时、流式看门狗、命令超时、子代理失速阈值、限流重试全部按最坏情况配置 |
| **A3 证据先行** | 协议字段、寄存器位、D-Bus 接口签名等**必须来自读到的真实代码/规范**，不允许凭模型记忆书写 | 工具输出（文件读取、命令输出、子代理回传、MCP 结果）在文档允许的上限内不截断；上游开源仓库可被直接检索与全文读取 |
| **A4 规范硬约束** | 编码规范、内存约束、安全启动链、许可证边界、"禁改区"必须被强制执行而非口头遵守 | CLAUDE.md 硬规则 + 构建/静态检查/测试的验证闭环，必要时以 deny 规则或 hooks 兜底 |
| **A5 大规模并行不互踩** | 代码审计、批量迁移需要几十上百个子代理并行，且互不污染工作区 | 子代理数量上限、后台任务能力、worktree 隔离、agent teams 全部启用且上限提高 |
| **A6 行为一致性** | 同一任务内模型行为不得漂移（换模型、换推理档、换系统提示都会改变行为） | 模型/effort 固定为单一配置；升级只发生在任务间隙（见第 13、14 章） |

### 1.2 场景 ②：A 股深度行情分析

A 股的特殊性在于：交易规则密集（T+1、分板块涨跌停、ST 制度、停复牌）、口径陷阱密集（复权、单位、报告期 vs 公告日）、信息面变化迅速（政策、公告、资金）。"绝对可靠的数据值"在 LLM 语境下只有一种实现方式：**模型的每一个数字都来自当轮工具调用的返回值，并可溯源**。硬需求：

| 编号 | 需求 | 判定标准 |
| --- | --- | --- |
| **B1 数据值绝对可靠** | 禁止模型凭参数记忆给出任何行情/财务数字；关键数字须双源交叉验证 | 每个数值可追溯到具体工具调用（接口名/URL + 获取时间）；检索与全文读取链路（Web Search / Web Reader MCP、本地数据接口）全程可用且结果不被截断 |
| **B2 口径先于计算** | 任何计算前先锁定：复权方式、单位（元/万元/亿元）、币种、时区、报告期与公告日、交易日历 | CLAUDE.md 中的口径声明规程强制执行（见 10.3 模板） |
| **B3 时点正确性** | 回看历史必须用时点数据（point-in-time），防幸存者偏差、防以"当前已知信息"解释历史 | 作业规程强制声明数据截止时间；停牌/退市/新股按规程单独处理 |
| **B4 考虑问题全面** | 多空两面、宏观—行业—个股—资金—情绪—估值多维检查，必须主动搜索反驳证据 | 深思考锁定 reasoning_effort=max（xhigh 档经 Z.AI 映射）；并行子代理/fork/workflow 分头核查；检查清单进 CLAUDE.md（见 10.4） |
| **B5 持续稳定复跑** | 盘后例行分析可无人值守运行，结论产物落盘存档、可审计 | bypassPermissions 全自动；无人值守重试；结论文件化；会话记录长期保留 |
| **B6 推理可审** | 深度结论的中间推理必须可见、可复查 | 思考过程全程开启且界面可展开审阅 |

## 2. 对"高缓存命中"的定调

本手册对该机制的定调如下：

1. **缓存是无损机制，与准确性零冲突**。提示缓存的本质是"逐字节精确匹配的前缀复用"——命中时服务端复用的是与重算**完全相同**的计算结果，不存在"命中缓存导致回答质量下降"的情形。因此它不需要被刻意追求，也不需要被防范：**保持默认开启即可**（关闭它不会换取任何精度，只会让每轮重算同样的内容）。
2. **本配置没有任何为缓存牺牲能力的设定**。唯一与缓存相关的参数 `CLAUDE_CODE_ATTRIBUTION_HEADER=0` 的作用是"从系统提示词开头移除客户端版本指纹块"——这是减少与任务无关的提示噪音，缓存收益属于附带效果。
3. **第 14 章"行为漂移源清单"的真正价值是一致性，而非费用**。中途切换模型、切换 effort、MCP 服务器断连、升级版本——这些操作的要害是**改变了模型的行为条件**（不同模型/档位/系统提示 = 不同的回答者），缓存重建只是其可观测的影子。该清单服务于 A6/B5，与费用无关。
4. **Z.AI 侧唯一与缓存相关且关乎精度的机制是 Preserved Thinking**（保留历史轮推理内容），官方明确其"提升模型表现"，且在 Coding Plan 端点**默认开启**、无需配置——它是精度特性，缓存命中率提升是副产品。

- 来源：[Claude Code – Prompt caching（前缀精确匹配机制）](https://code.claude.com/docs/en/prompt-caching)、[Z.AI – Thinking Mode（Preserved thinking）](https://docs.z.ai/guides/capabilities/thinking-mode)、[Claude Code – env-vars（`CLAUDE_CODE_ATTRIBUTION_HEADER`）](https://code.claude.com/docs/en/env-vars)

## 3. 模型策略：全链路单旗舰

单一模型覆盖全链路，包括后台辅助任务与子代理在内。设计原则：模型切换即行为漂移（A6），任何"备选 / 回退 / 轻量位"都构成正确性风险。具体策略：

- **四个别名位全部 GLM-5.2**，`/model` 选单中不设任何备选项——"更快的备选"并无对应需求场景，保留于选单反而构成误操作切换模型的风险点；
- **后台辅助功能（Haiku 位）同样采用旗舰**：官方定义该位承担会话标题生成等后台环节，WebFetch 工具的网页内容抽取也由"小而快的模型"执行——本配置原则为全链路采用最强模型，辅助环节不使用次级模型。WebFetch 为"有损抽取"设计（见第 8 章与 10.2），抽取模型升至旗舰后损失进一步减小；
- **`fallbackModel` 保持不设置**：模型过载时宁可按第 7.6 节的看门狗无限重试同一模型，也不允许静默降级到任何其他模型出活（降级产物不可信，违反 A6/B1）。

模型矩阵——**四个别名位全部 GLM-5.2，无任何备选、无任何回退**：

| Claude Code 模型位 | 值 | 承担的工作 |
| --- | --- | --- |
| Opus 位 | `glm-5.2[1m]` | 主会话（默认 `model: "opus"`） |
| Sonnet 位 | `glm-5.2[1m]` | 任何解析到 sonnet 别名的路径（含 `opusplan` 执行阶段等） |
| Fable 位 | `glm-5.2[1m]` | 误触 `/model fable` / `best` 时的兜底 |
| Haiku 位 | `glm-5.2` | 后台辅助功能（标题、WebFetch 抽取等）。注：`[1m]` 后缀官方仅对 Opus/Sonnet 位提供文档保证，Haiku 位任务本身极短，无需 1M 声明 |
| 子代理 | `CLAUDE_CODE_SUBAGENT_MODEL: "opus"` → glm-5.2[1m] | 强制覆盖一切子代理/agent team/workflow 的模型指定，即使子代理定义试图指定较低规格模型（如 haiku），也会被统一至 GLM-5.2 |

- 来源：[Claude Code – env-vars（`ANTHROPIC_DEFAULT_HAIKU_MODEL`＝"Name of Haiku-class model for background tasks"、`CLAUDE_CODE_SUBAGENT_MODEL`）](https://code.claude.com/docs/en/env-vars)、[Claude Code – Tools reference（WebFetch "runs the prompt against the content using a small, fast model"）](https://code.claude.com/docs/en/tools-reference)、[Claude Code – Model configuration（别名机制、`[1m]` 后缀、Fallback model chains）](https://code.claude.com/docs/en/model-config)、[Z.AI – FAQ（Coding Plan 端点允许的模型列表）](https://docs.z.ai/devpack/faq)

## 4. 需求 → 配置追溯矩阵

| 需求 | 对应配置/机制 | 详解章节 |
| --- | --- | --- |
| A1 跨栈上下文 | `glm-5.2[1m]` 全别名位、`CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000`、`CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000`、`CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1`、`CLAUDE_CODE_GLOB_TIMEOUT_SECONDS=60` | 7.2 / 7.4 |
| A2 长周期执行 | `API_TIMEOUT_MS=3000000`、`API_FORCE_IDLE_TIMEOUT=0`、`CLAUDE_STREAM_IDLE_TIMEOUT_MS=1800000`、`CLAUDE_CODE_RETRY_WATCHDOG=1`、`BASH_MAX_TIMEOUT_MS=3600000`、`CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS=3600000` | 7.6 |
| A3 证据先行 | `BASH_MAX_OUTPUT_LENGTH=150000`、`TASK_MAX_OUTPUT_LENGTH=160000`、`MAX_MCP_OUTPUT_TOKENS=50000`、`CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS=65536`、Zread/Web Reader MCP | 7.5 / 11 |
| A4 规范硬约束 | CLAUDE.md 模板、验证闭环规程、（可选）项目级 deny/hooks | 9.2–9.4 |
| A5 大规模并行 | `CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION=1000`、`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`、`CLAUDE_CODE_FORK_SUBAGENT=1`、worktree、ultracode workflow 通道（effort 锁定 `xhigh`） | 7.10 / 9.5 |
| A6 / B5 行为一致性 | 全 5.2 单模型、effort 环境变量锁定（xhigh→max）、不设 fallback、升级 SOP、漂移源清单 | 3 / 7.3 / 13 / 14 |
| B1 数据可靠 | 四个 Z.AI MCP + `skipWebFetchPreflight`、数据铁律规程、抽取模型升至 5.2 | 10.2 / 11 |
| B2/B3 口径与时点 | A 股 CLAUDE.md 模板（口径声明块、时点规程） | 10.3 |
| B4 全面性 | `reasoning_effort=max` 锁定、fork/子代理并行核查、检查清单 | 7.3 / 10.4 |
| B5 持续复跑 | bypassPermissions、无人值守重试、headless 例行任务、`cleanupPeriodDays=365` | 7.9 / 10.5 |
| B6 推理可审 | `alwaysThinkingEnabled`、`showThinkingSummaries`、Preserved Thinking | 7.3 |

---

# 第二部分：配置

## 5. 工作原理速览

### 5.1 网关模式

Claude Code 通过 `ANTHROPIC_BASE_URL` 将全部模型请求改发至兼容 Anthropic Messages 协议的端点；该变量仅改变"请求发往何处"，不改变"哪个模型回答"。Z.AI Coding Plan 的 Anthropic 协议专属端点为 `https://api.z.ai/api/anthropic`（使用普通 API 端点会脱离套餐计费并产生 1113 余额错误）。

- 来源：[Claude Code – Model configuration](https://code.claude.com/docs/en/model-config)、[Z.AI – Quick Start（Endpoint Guide）](https://docs.z.ai/devpack/quick-start)、[Z.AI – FAQ](https://docs.z.ai/devpack/faq)

### 5.2 别名映射与 effort 映射

模型别名（opus/sonnet/haiku/fable）由 `ANTHROPIC_DEFAULT_*_MODEL` 解析（见第 3 章矩阵）。Claude Code 的 effort 档位经 Z.AI 端点映射为 GLM-5.2 的 `reasoning_effort`：

| Claude Code effort | GLM-5.2 reasoning_effort |
| --- | --- |
| `low` / `medium` / `high` | `high` |
| `xhigh` / `max` / `ultracode` | **`max`**（GLM-5.2 的最深推理档，也是其 API 默认值） |

- 来源：[Z.AI – How to Switch Models（映射表）](https://docs.z.ai/devpack/latest-model)、[Z.AI – Deep Thinking / Core Parameters（`reasoning_effort` 语义）](https://docs.z.ai/guides/capabilities/thinking)

### 5.3 两层缓存（背景知识，非优化目标）

Claude Code 侧为前缀精确匹配的提示缓存；Z.AI 侧为隐式自动缓存（`usage.prompt_tokens_details.cached_tokens` 可见），且 Coding Plan 端点默认开启 Preserved Thinking。定调见第 2 章，漂移源清单见第 14 章。

- 来源：[Claude Code – Prompt caching](https://code.claude.com/docs/en/prompt-caching)、[Z.AI – Context Caching](https://docs.z.ai/guides/capabilities/cache)、[Z.AI – Thinking Mode](https://docs.z.ai/guides/capabilities/thinking-mode)

## 6. 配置文件位置、生效时机与验证

| 作用域 | Windows 路径 | 影响范围 |
| --- | --- | --- |
| **用户级（本配置使用）** | `%USERPROFILE%\.claude\settings.json` | 当前用户、所有项目 |
| 项目级（共享） | `<项目>\.claude\settings.json` | 该仓库所有协作者 |
| 项目级（本地） | `<项目>\.claude\settings.local.json` | 当前用户、仅该仓库 |
| 托管策略 | `C:\Program Files\ClaudeCode\managed-settings.json` 等 | 全机器，最高优先级 |

要点：

- 优先级：托管 > 命令行 > 项目本地 > 项目共享 > 用户级；**数组类设置（如 `permissions.allow`）跨作用域合并**而非覆盖。
- 环境变量与设置字段并存时**环境变量优先**；同一变量在 shell 与 settings 的 `env` 块并存时 **`env` 块优先**（启动时写入进程环境覆盖 shell 值）——因此一切变量集中配置于 `env` 块。
- settings 文件被监视并**热加载**大部分键；`model`、`outputStyle` 等在下次启动/`/model` 时生效。
- 验证：`/status`（Setting sources 与 Model）、`/context`（窗口占用）、`/mcp`（MCP 状态）、`claude doctor`（健康检查）。

部署步骤：

1. 将仓库根目录 [`settings.json`](./settings.json) 部署至 `%USERPROFILE%\.claude\settings.json`，并将 `ANTHROPIC_AUTH_TOKEN` 的占位值替换为实际的 Z.AI API Key（Z.AI 控制台 → Individual Coding Plan → Plan Overview 创建）。
2. 关闭全部既有会话窗口后重新启动 `claude`，首次提示 "Do you want to use this API key?" 时选择 Yes。

安全提示：settings.json 中包含明文 API Key。将该文件提供给任何第三方、进行截图分享或提交至公开仓库之前，必须先移除 Key；已暴露的 Key 应立即在 Z.AI 控制台轮换。

- 来源：[Claude Code – Settings（scopes / precedence / 热加载 / 验证）](https://code.claude.com/docs/en/settings)、[Claude Code – env-vars（Precedence）](https://code.claude.com/docs/en/env-vars)、[Z.AI – Claude Code 接入](https://docs.z.ai/devpack/tool/claude)

## 7. 参数逐项详解

除特别说明外，`env` 值一律为**字符串**。每项给出：名称、值、含义与理由、来源。

### 7.1 接入与认证

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.ANTHROPIC_BASE_URL` | `https://api.z.ai/api/anthropic` | Coding Plan 专属 Anthropic 协议端点。结尾不带 `/`。 |
| `env.ANTHROPIC_AUTH_TOKEN` | 使用者的 Z.AI API Key | 以 `Authorization: Bearer` 发送。**系统中不得残留 `ANTHROPIC_API_KEY`**，避免双认证冲突。 |

- 来源：[Z.AI – Claude Code 接入](https://docs.z.ai/devpack/tool/claude)、[Claude Code – env-vars（两变量条目）](https://code.claude.com/docs/en/env-vars)

### 7.2 模型矩阵（全 5.2）

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.ANTHROPIC_DEFAULT_OPUS_MODEL` | `glm-5.2[1m]` | 主力位。`[1m]` 使 Claude Code 按 1M 窗口管理会话，发送前自动剥除后缀。 |
| `env.ANTHROPIC_DEFAULT_SONNET_MODEL` | `glm-5.2[1m]` | 覆盖一切解析到 sonnet 的路径。 |
| `env.ANTHROPIC_DEFAULT_FABLE_MODEL` | `glm-5.2[1m]` | 覆盖 `fable`/`best` 别名路径。 |
| `env.ANTHROPIC_DEFAULT_HAIKU_MODEL` | `glm-5.2` | **后台辅助功能同样采用旗舰模型**（第 3 章）。`[1m]` 后缀在 Haiku 位无官方文档保证且后台任务极短，故使用裸模型名——这是文档边界内的最强配置。 |
| `env.CLAUDE_CODE_SUBAGENT_MODEL` | `opus` | 强制所有子代理/agent teams/workflow agent 走 opus 别名（=glm-5.2[1m]），并覆盖子代理定义中的任何 model 指定。 |
| `model`（顶层） | `opus` | 会话启动模型显式声明，杜绝默认值漂移。 |
| `env.ANTHROPIC_DEFAULT_*_MODEL_NAME` / `_DESCRIPTION` | `GLM-5.2 (1M)` 等 | `/model` 选择器显示名（官方说明 `_NAME`/`_DESCRIPTION` 在网关模式生效）。 |
| `env.ANTHROPIC_DEFAULT_*_MODEL_SUPPORTED_CAPABILITIES` | `effort,xhigh_effort,max_effort,thinking,adaptive_thinking,interleaved_thinking`（四个位一致） | 向 Claude Code 声明自定义模型 ID 支持的能力，解锁 effort 滑杆、xhigh/max 档、思考渲染、工具间思考。四个位均为 GLM-5.2，能力声明统一设置为最大。官方文档明确该变量在第三方 provider 生效、网关场景以 `CLAUDE_CODE_ALWAYS_ENABLE_EFFORT` 为主保险（7.3），此处为无副作用的冗余保险。 |

- 来源：[Claude Code – Model configuration（Environment variables / `[1m]` / Customize pinned model display and capabilities）](https://code.claude.com/docs/en/model-config)、[Z.AI – How to Switch Models](https://docs.z.ai/devpack/latest-model)

### 7.3 思考深度：锁定 reasoning_effort=max（A6 / B4 / B6）

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.CLAUDE_CODE_EFFORT_LEVEL` | `xhigh` | **锁定档**。环境变量是 effort 的最高优先级来源（高于 `/effort` 与 `effortLevel` 设置），锁定效果与 `max` 完全相同。之所以锁定 `xhigh` 而非 `max`：① 经 Z.AI 映射，`xhigh` 与 `max` 均落到 GLM-5.2 的 `reasoning_effort=max`，**推理深度无差别**；② 官方明确"当 `CLAUDE_CODE_EFFORT_LEVEL` 被设为 xhigh 以外的档位时，请求按该档执行且 **ultracode 的 workflow 编排保持关闭**"——即锁定 `max` 会随之关闭 ultracode 的动态工作流编排（A5 大规模并行审计、B4 多角度交叉核查的主力通道），而 ultracode 本身发送给模型的本就是 `xhigh`。锁定 `xhigh` 即以相同的最深推理保留自动编排通道，为严格占优的选择。 |
| `effortLevel`（顶层） | `xhigh` | 冗余保障层：若上述环境变量被移除，会话仍持久落在 xhigh——经 Z.AI 映射仍是 `reasoning_effort=max`，双重保障。 |
| `env.CLAUDE_CODE_ALWAYS_ENABLE_EFFORT` | `1` | Claude Code 默认仅对其识别的 Claude 模型 ID 发送 effort 参数；`glm-5.2` 是自定义 ID，不设此项 effort 可能根本不随请求发出。官方原文："Use this when routing through an LLM gateway or third-party provider that serves models under custom identifiers." |
| `alwaysThinkingEnabled`（顶层） | `true` | 所有会话默认扩展思考。GLM-5.2 在 Coding Plan 端点本就默认 `thinking.type=enabled`，此项保证客户端不发出关闭思考的请求形态。 |
| `showThinkingSummaries`（顶层） | `true` | 思考内容在界面可见（`Ctrl+O` 展开）——B6"推理可审"的界面开关。A 股结论必须回看推理链；BMC 大改动前亦应审查其方案推演。 |

配额倍率提示（可用性视角，非费用视角）：GLM-5.2 属 Opus 级模型，峰时 3×、非峰 2× 计入套餐配额。这不改变任何决策——触及 5 小时窗口上限时按第 12 章切换账号即可。

- 来源：[Claude Code – Model configuration（Adjust effort level：max 持久化例外条款、优先级顺序）](https://code.claude.com/docs/en/model-config)、[Claude Code – env-vars（`CLAUDE_CODE_EFFORT_LEVEL`、`CLAUDE_CODE_ALWAYS_ENABLE_EFFORT`）](https://code.claude.com/docs/en/env-vars)、[Claude Code – Settings（`alwaysThinkingEnabled`、`showThinkingSummaries`、`effortLevel`）](https://code.claude.com/docs/en/settings)、[Z.AI – How to Switch Models（effort 映射、max 推荐）](https://docs.z.ai/devpack/latest-model)、[Z.AI – Coding Plan Overview（倍率）](https://docs.z.ai/devpack/overview)

### 7.4 上下文：真 1M（A1）

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.CLAUDE_CODE_AUTO_COMPACT_WINDOW` | `1000000` | 自动压缩的容量基准。Z.AI 官方要求启用 1M 时配套设置，否则可能按 200K 提前压缩——**提前压缩 = 证据被摘要替换**，是 A1/A3 的首要威胁。 |
| `env.CLAUDE_CODE_MAX_CONTEXT_TOKENS` | `1000000` | 显式声明窗口大小；对 Claude Code 不识别的模型名（glm-5.2）直接生效（v2.1.193+）。与 `[1m]` 后缀互为双重保障。 |
| `env.CLAUDE_CODE_MAX_OUTPUT_TOKENS` | `131072` | 单请求输出上限 = GLM-5.2 的 `max_tokens` 硬上限（默认 65536）。整文件重写、长分析报告单轮完成，不因输出配额被截断。**知情权衡**（官方明示"提高该值会减少触发 auto-compaction 前的可用上下文"）：1M 窗口下压缩前有效空间约降至 87 万 token，属可接受代价；超长会话末期若压缩早于预期，按 9.4 落盘规程对冲。 |
| `env.CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` | `1` | **多仓库工作区关键项**：默认情况下 `--add-dir`/`/add-dir` 挂载的目录**不加载**其 CLAUDE.md/规则文件；置 1 后各仓库的 `CLAUDE.md`、`.claude/rules/*.md`、`CLAUDE.local.md` 全部载入。BMC 场景将 u-boot、kernel、openbmc、webui 各自的工程约定同时载入上下文（A1/A4）。 |
| `env.CLAUDE_CODE_GLOB_TIMEOUT_SECONDS` | `60` | Glob 文件发现超时从默认 20 秒提高到 60 秒（官方在 WSL 上的默认值）。Yocto 全量源码树等超大目录的检索不因超时遗漏文件（A1/A3）。 |

**不设** `CLAUDE_CODE_DISABLE_1M_CONTEXT`（按 200K 处理）与 `DISABLE_AUTO_COMPACT`/`DISABLE_COMPACT`（窗口占满时压缩是避免请求直接失败的最后防线；配合第 9/10 章"关键证据落盘"规程，压缩造成的损失可控）。

- 来源：[Z.AI – How to Switch Models（Enable 1M Context）](https://docs.z.ai/devpack/latest-model)、[Z.AI – GLM-5.2（1M/128K 规格）](https://docs.z.ai/guides/llm/glm-5.2)、[Z.AI – Core Parameters（max_tokens 表）](https://docs.z.ai/guides/overview/concept-param)、[Claude Code – env-vars（各变量条目）](https://code.claude.com/docs/en/env-vars)

### 7.5 证据不截断（A3 / B1）

| 参数 | 值 | 默认 | 含义与理由 |
| --- | --- | --- | --- |
| `env.CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` | `65536` | 内置较小值 | 单次文件读取 token 上限。长驱动源文件、长财报文本尽量整读入上下文而非分页。（可继续上调，但单文件占用 1M 窗口比例过大反而挤压推理空间，65536≈250KB 文本是证据完整性与推理余量的平衡点。） |
| `env.BASH_MAX_OUTPUT_LENGTH` | `150000` | 30000 | 命令输出直接进入上下文的字符上限，**150000 为官方硬上限**。构建日志、回测输出超限时转存文件并提供路径，模型可继续检索。 |
| `env.MAX_MCP_OUTPUT_TOKENS` | `50000` | 25000 | MCP 响应 token 上限，长网页/长源码文件（Web Reader、Zread）不被截断。 |
| `env.TASK_MAX_OUTPUT_LENGTH` | `160000` | 32000 | 子代理回传上限，**160000 为官方最大值**。子代理的调研结论是证据链核心载体，设置为最大值。 |
| `env.BASH_DEFAULT_TIMEOUT_MS` | `600000` | 120000 | 命令默认超时 10 分钟。 |
| `env.BASH_MAX_TIMEOUT_MS` | `3600000` | 600000 | 模型可请求的命令超时上限 1 小时（bitbake 单包构建、长回测）。超时不等于被终止：到时命令转入后台继续执行。 |

- 来源：[Claude Code – env-vars（各变量条目）](https://code.claude.com/docs/en/env-vars)、[Claude Code – Tools reference（Bash 输出/超时/自动转后台行为）](https://code.claude.com/docs/en/tools-reference)

### 7.6 传输可靠性（A2 / B5）

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.API_TIMEOUT_MS` | `3000000` | 单请求总超时 50 分钟（Z.AI 官方脚本值；默认仅 10 分钟）。max 档深思考 + 1M 预填充的最坏情况兜底。 |
| `env.API_FORCE_IDLE_TIMEOUT` | `0` | 关闭"流式 5 分钟无字节即中止"的定时器（非 Anthropic 直连时默认开启）。官方明确 `0` 用于块间停顿超过 5 分钟的网关/模型场景——深思考停顿被误中断正是"中途截断"的典型来源。 |
| `env.CLAUDE_STREAM_IDLE_TIMEOUT_MS` | `1800000` | 流式空闲看门狗放宽到 30 分钟（显式设置的官方下限为 5 分钟）。保留最终兜底：确认失效的连接在 30 分钟后仍会被切断并进入重试，不会无限挂起。 |
| `env.CLAUDE_ENABLE_BYTE_WATCHDOG` | `1` | **字节级**流式看门狗。它与事件级看门狗互补：事件级监测"是否解析出 SSE 事件"，字节级监测"线路上是否存在任何字节"。网关连接下字节级默认**关闭**（官方：仅 Anthropic 直连/Claude Platform on AWS 默认开启），显式开启补上该防护层；官方明确其阈值复用 `CLAUDE_STREAM_IDLE_TIMEOUT_MS` 的值——即同样为 30 分钟，不会误中断深思考停顿。 |
| `env.CLAUDE_CODE_RETRY_WATCHDOG` | `1` | 无人值守级重试：429/529 无限重试（按限额重置时间或最长 5 分钟退避等待），其余瞬时错误默认重试提高到 300 次（约 3 小时退避）。官方推荐用于 unattended sessions——B5 盘后无人值守的基石。 |
| `env.CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK` | `1` | 流式中断时禁止回退为非流式重发——官方指出该回退经代理/网关时可能**重复执行工具**。对金融数据写入、git 操作，重复执行属于正确性事故；禁用后错误统一进入上述重试层。 |
| `env.MCP_TIMEOUT` | `120000` | MCP 服务器**启动连接**超时 2 分钟（默认 30 秒）；Vision MCP 首次启动需 npx 现场拉取包。 |
| `env.MCP_TOOL_TIMEOUT` | `1800000` | MCP 工具**执行**超时。关键在第二重语义：HTTP 型 MCP（Z.AI 三个远程服务器）**单请求默认 60 秒**超时，将本变量提高到 60000 以上才能提升单请求上限——长公告全文、大仓库结构不再被 60 秒截断（B1/A3）。注意本值同时将总执行上限从默认约 28 小时收窄到 30 分钟：对检索/读页类工具绰绰有余，属有意为之（单次挂起 30 分钟的取数调用应进入重试，而非持续占用一天）。 |
| `env.CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT` | `600000` | MCP 工具执行的**空闲**判定：网络型服务器默认 5 分钟无响应即中止，提高到 10 分钟，容纳 web-reader 慢页面、zread 大仓库的长停顿（官方要求该值不超过 `MCP_TOOL_TIMEOUT`，600000 < 1800000 合规；需 v2.1.187+）。 |
| `env.CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS` | `0` | 关闭"MCP 调用超过 2 分钟自动转后台"（默认 120000；需 v2.1.212+）。理由是**证据顺序**而非仅可见性：取数调用被静默转入后台后，模型可能在数据到达前继续推进论证，事后再补挂结果——这违背 B1"先有证据、后有结论"的时序。关闭后取数调用同步完成、结果按序进入推理链。BMC 的长构建走 Bash 后台任务，不受此项影响。 |

- 来源：[Claude Code – env-vars（各变量条目，含 `CLAUDE_ENABLE_BYTE_WATCHDOG` 复用 `CLAUDE_STREAM_IDLE_TIMEOUT_MS`、`MCP_TOOL_TIMEOUT` 60 秒单请求条款、idle 上限条款）](https://code.claude.com/docs/en/env-vars)、[Z.AI – Claude Code 接入（`API_TIMEOUT_MS=3000000`）](https://docs.z.ai/devpack/tool/claude)

### 7.7 提示词纯净（附带缓存收益）

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.CLAUDE_CODE_ATTRIBUTION_HEADER` | `0` | 移除系统提示词开头的客户端版本/指纹归因块：减少与任务无关的提示噪音；官方另注明此项提升网关场景缓存命中——按第 2 章定调，属附带收益。 |

- 来源：[Claude Code – env-vars（`CLAUDE_CODE_ATTRIBUTION_HEADER`）](https://code.claude.com/docs/en/env-vars)

### 7.8 无法直连 Anthropic 的网络适配

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | `1` | 关闭全部非必要外联：后台自动更新、遥测、错误上报、`/feedback`、发行说明、模型发现刷新、可用性检查。在无法访问 Anthropic 的日常环境中，这些请求仅产生超时报错并拖慢会话。Z.AI 官方接入文档同样建议设置。手动 `claude update` 不受影响。 |
| `env.DISABLE_ERROR_REPORTING` / `env.DISABLE_TELEMETRY` | `1` / `1` | 显式双重保障；`DISABLE_TELEMETRY` 使特性开关采用代码默认值，行为更确定。 |
| `skipWebFetchPreflight`（顶层） | `true` | **关键项**：WebFetch 默认对每个 URL 先向 `api.anthropic.com` 发起域名安全预检；本环境无法访问 Anthropic，不跳过则 WebFetch 整体不可用（直接破坏 B1 数据链路）。官方明确此项用于 "environments that block traffic to Anthropic"。 |
| `autoUpdatesChannel`（顶层） | `latest` | 手动升级时跟随最新通道，配合主动持续跟踪升级的策略。 |

已知的自然结论：内置 `WebSearch` 是 Anthropic 服务端工具，网关模式下大概率不可用（官方明示"需要其他搜索来源时应接入提供搜索工具的 MCP"）——Z.AI Web Search MCP 即为其正式替代；claude.ai 登录态功能（Artifacts、Remote Control、Routines 等）在纯 API Token 模式下不可用，属预期行为。

- 来源：[Claude Code – env-vars（`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` 等）](https://code.claude.com/docs/en/env-vars)、[Claude Code – Settings（`skipWebFetchPreflight`、`autoUpdatesChannel`）](https://code.claude.com/docs/en/settings)、[Claude Code – Tools reference（WebSearch tool behavior）](https://code.claude.com/docs/en/tools-reference)、[Z.AI – Claude Code 接入](https://docs.z.ai/devpack/tool/claude)

### 7.9 Windows 专项与自动化权限

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.CLAUDE_CODE_USE_POWERSHELL_TOOL` | `1` | 启用原生 PowerShell 工具（安装了 Git Bash 的机器上该工具默认"逐步放量"，显式置 1 立即启用）。自动优先选择 `pwsh.exe`，回退 `powershell.exe`，进程级 `-ExecutionPolicy Bypass` 保证 `.ps1` 可执行。Bash 工具保留用于 POSIX 脚本。 |
| `defaultShell`（顶层） | `powershell` | 输入框 `!` 手动执行的命令走 PowerShell。 |
| `permissions.defaultMode` | `bypassPermissions` | 默认全自动。残留提示仅包括：显式 ask 规则（未设置）、标记 `requiresUserInteraction` 的 MCP 工具、`rm -rf /`/`rm -rf ~` 断路器（v2.1.208 起含 `$(...)` 变体）。 |
| `skipDangerousModePermissionPrompt`（顶层） | `true` | 跳过进入 bypass 模式的确认弹窗（用户级设置有效，项目级会被忽略）。 |
| `permissions.allow` | 18 条 | Shift+Tab 切换到 manual/acceptEdits/plan 模式时的免批清单，见下文。 |
| `permissions.deny` | `[]` | deny 在**一切模式（含 bypass）**下生效，与全自动目标冲突，故保持为空。涉及真实资金的实盘接口防线见 10.6（项目级窄 deny 是官方提供的唯一硬闸）。 |

允许列表设计（工具名以 [tools reference](https://code.claude.com/docs/en/tools-reference) 的权威名为准）：

- `Bash`、`PowerShell`：任意命令；`Read`、`Glob`、`Grep`、`LSP`：读取与搜索（放行后**工作目录之外**的读取同样免批——跨盘符数据目录、下载目录等 Windows 常见场景）；`Edit`、`Write`、`NotebookEdit`：全部文件修改；`WebFetch`、`WebSearch`：网页抓取/搜索；`Agent`、`Skill`、`Monitor`：子代理、技能、后台监视；`mcp__zai-mcp-server`、`mcp__web-search-prime`、`mcp__web-reader`、`mcp__zread`：四个专属 MCP 的全部工具（`mcp__<server>` 裸规则匹配该服务器所有工具）。
- **allow 清单的第三重身份**：workflow 调度的子代理**强制运行在 `acceptEdits` 模式并继承此 allowlist，不继承主会话的 bypass**（官方原文："The subagents the workflow spawns always run in `acceptEdits` mode and inherit your tool allowlist, regardless of your session's mode"）。因此即便常驻 bypass，这 18 条也并非冗余——它们是 workflow 大规模并行时的免批通行证；headless 模式下不在清单内的调用会被直接拒绝（"no one to prompt ... follow your configured permission rules without interactive confirmation"）。新部署的 MCP 如需 workflow 使用，应先将 `mcp__<server>` 加入本清单。
- **有意不放行** `ExitPlanMode`：计划审批保留人工闸门——BMC 级大改动先出计划、经确认后执行，是 A4 的低成本高收益环节。
- `Workflow`/`EnterWorktree` 因当前发布的官方 JSON Schema 尚未收录而未列入（官方声明 schema 可能滞后于最新 CLI；两者仅在非 bypass 模式的少数情形弹窗，影响极小，追求绝对零弹窗可自行加回）。
- Shift+Tab 循环为 `manual → acceptEdits → plan → bypassPermissions`（bypass 因 defaultMode 声明而进入循环）；auto 模式依赖 Anthropic 侧分类器与特定 Claude 模型，GLM 网关下不可用、不会出现在循环中。

- 来源：[Claude Code – Tools reference（PowerShell tool、权威工具名）](https://code.claude.com/docs/en/tools-reference)、[Claude Code – Permissions（规则语法、deny 全模式生效、断路器）](https://code.claude.com/docs/en/permissions)、[Claude Code – Permission modes（模式循环与 bypass 进入循环条件、auto 可用性要求）](https://code.claude.com/docs/en/permission-modes)、[Claude Code – Settings（Permission settings、schema 滞后声明）](https://code.claude.com/docs/en/settings)

### 7.10 大规模并行与长任务编排（A5）

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION` | `1000` | 单会话子代理上限从默认 200 提高到 1000（官方：正整数、无上限、仅可调高）。BMC 全仓审计/批量迁移通过 workflow 并行调度上百子代理属常态操作。 |
| `env.CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS` | `3600000` | 后台子代理"失速"判定从默认 10 分钟放宽到 1 小时——子代理内部单条长构建/长回测命令期间可能没有流式进度事件，默认值会将其误判为失败（A2）。超过 1 小时的构建应改用 `run_in_background` 的后台命令而非阻塞式子代理。 |
| `env.CLAUDE_CODE_FORK_SUBAGENT` | `1` | 启用 fork 型子代理：**继承完整对话上下文**开分支，而非空白起步。金融场景用它并行核查对立假设（多/空论证各 fork 一支，证据不丢失）；工程场景用它在不污染主线的情况下试探激进方案。 |
| `env.CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS` | `0` | headless（`claude -p`）模式默认仅等待后台子代理与 workflow **10 分钟**，超时后"remaining background tasks are terminated and the process exits"——即无人值守的深度 workflow 会在 10 分钟被终止，这正是 B5 场景最隐蔽的截断源。官方明确 `0` = 无限等待。交互式会话不受此变量影响。（需 v2.1.182+） |
| `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `1` | 启用实验性 agent teams（主管+队友多实例协作）。队友模型无论按别名解析还是继承主会话，均落在 GLM-5.2（全部别名位已对齐，且 `CLAUDE_CODE_SUBAGENT_MODEL` 兜底）。实验性特性，异常时删除此行即可。 |

- 来源：[Claude Code – env-vars（`CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION`、`CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS`、`CLAUDE_CODE_FORK_SUBAGENT`、`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`）](https://code.claude.com/docs/en/env-vars)、[Claude Code – Tools reference（Agent tool / 后台任务）](https://code.claude.com/docs/en/tools-reference)

### 7.11 留痕与其他

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `cleanupPeriodDays` | `365` | 会话转录保留一年（默认 30 天清理）。分析会话 = 审计底稿（B5）；配合 `/resume` 回溯。可按需继续加大。 |
| `attribution.commit`/`attribution.pr` | `""`/`""` | 关闭提交/PR 中的 Claude 署名（新版 `attribution` 键取代已废弃的 `includeCoAuthoredBy`）。 |
| `language` | `chinese-simplified` | 默认中文回复（亦影响自动会话标题语言）。 |
| `$schema` | schemastore 地址 | 编辑器内自动补全与校验。 |

- 来源：[Claude Code – Settings（`cleanupPeriodDays`、Attribution settings、`language`、`$schema`）](https://code.claude.com/docs/en/settings)

## 8. 有意不设置的参数及原因

| 参数 | 决定 | 原因 |
| --- | --- | --- |
| `fallbackModel` | **绝不设置** | 过载时自动切换模型 = 静默降级出活，违反 A6/B1。策略：`CLAUDE_CODE_RETRY_WATCHDOG` 持续重试同一模型，无法等待时按第 12 章切换账号。来源：[Model configuration – Fallback model chains](https://code.claude.com/docs/en/model-config) |
| `CLAUDE_CODE_EXTRA_BODY`（如注入 `temperature`/`top_p`） | 不设置 | 直觉上金融场景倾向低温度采样，但工程判断为不注入：① Anthropic 协议下扩展思考与采样参数存在兼容约束，网关对自定义组合的处理无官方保证，注入即引入未定义行为；② GLM-5.2 官方迁移指南明示默认 `temperature=1.0`、`top_p=0.95`、"recommend choosing only one for tuning"——这是其深思考模式的标定工况；③ **数值的确定性由"工具算数"保证**（10.2 铁律：所有计算落到代码执行），不依赖采样温度。来源：[Z.AI – Migrate to GLM-5.2（Migration Checklist 采样默认值）](https://docs.z.ai/guides/overview/migrate-to-glm-new)、[Z.AI – Core Parameters](https://docs.z.ai/guides/overview/concept-param)、[Claude Code – env-vars（`CLAUDE_CODE_EXTRA_BODY`）](https://code.claude.com/docs/en/env-vars) |
| `MAX_THINKING_TOKENS` | 不设置 | 设 0 会关闭思考；非零值属"固定思考预算"模型的机制。GLM-5.2 思考深度由 `reasoning_effort` 控制且已锁定（7.3）。来源：[Claude Code – env-vars](https://code.claude.com/docs/en/env-vars) |
| `DISABLE_PROMPT_CACHING`（及分模型变体） | 绝不设置 | 缓存是无损机制（第 2 章），关闭无任何收益。来源：[Prompt caching](https://code.claude.com/docs/en/prompt-caching) |
| `ENABLE_PROMPT_CACHING_1H` / `FORCE_PROMPT_CACHING_5M` | 不设置 | Anthropic 官方缓存 TTL 计费选项，Z.AI 隐式缓存不适用。来源：[Prompt caching – Cache lifetime](https://code.claude.com/docs/en/prompt-caching)、[Z.AI – Context Caching](https://docs.z.ai/guides/capabilities/cache) |
| `ENABLE_TOOL_SEARCH` | 保持默认 | 非第一方 host 默认预载全部 MCP 工具（tool search 需网关支持 `tool_reference`，Z.AI 未声明支持，强制开启会导致请求失败）。来源：[env-vars（`ENABLE_TOOL_SEARCH`）](https://code.claude.com/docs/en/env-vars) |
| `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` | 默认不设 | 仅当端点对 `anthropic-beta` 头报错时临时置 1。来源：[env-vars](https://code.claude.com/docs/en/env-vars) |
| `DISABLE_INTERLEAVED_THINKING` | 不设置 | GLM 自 4.5 起默认支持工具间思考——"每个工具结果均被推理消化"正是 A3/B4 的要求。来源：[Z.AI – Thinking Mode](https://docs.z.ai/guides/capabilities/thinking-mode) |
| `DISABLE_AUTO_COMPACT` / `DISABLE_COMPACT` | 不设置 | 窗口占满时压缩是避免请求直接失败的最后防线；损失由"关键证据落盘"规程（9.4/10.5）对冲。来源：[env-vars](https://code.claude.com/docs/en/env-vars) |
| `CLAUDE_CODE_DISABLE_1M_CONTEXT` | 绝不设置 | 会按 200K 窗口处理。来源：[env-vars](https://code.claude.com/docs/en/env-vars) |
| `ANTHROPIC_API_KEY` | 不设置 | Z.AI 使用 `ANTHROPIC_AUTH_TOKEN`；系统中残留的 `ANTHROPIC_API_KEY` 必须删除。来源：[env-vars](https://code.claude.com/docs/en/env-vars) |
| `CLAUDE_CODE_ENABLE_FINE_GRAINED_TOOL_STREAMING=1` | 可选未启用 | 网关下细粒度工具流默认关闭，仅影响"大段写入的实时观感"，不影响结果；启用属观感优化，若遇工具参数解析错误须移除。来源：[env-vars](https://code.claude.com/docs/en/env-vars) |
| `CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY` | 保持默认 10 | 可提高并行度，但并发受 Z.AI 套餐侧动态限制（Max 档更高、非峰更宽），超发只会产生 429-重试循环。需要更高吞吐时应使用多会话/多账号（第 12 章）。来源：[env-vars（`CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY`）](https://code.claude.com/docs/en/env-vars)、[Z.AI – Usage Policy](https://docs.z.ai/devpack/usage-policy) |
| `sandbox.*` | 不设置 | 沙箱仅支持 macOS/Linux/WSL2；Windows 原生 PowerShell 工具不支持沙箱。来源：[Settings – Sandbox settings](https://code.claude.com/docs/en/settings)、[Tools reference – PowerShell preview limitations](https://code.claude.com/docs/en/tools-reference) |

---

# 第三部分：作业手册

## 9. 场景 ①：BMC 级超大代码体系开发

### 9.1 工作区形态

推荐"主仓启动 + 多目录挂载"：在主工作仓（如 openbmc 或自定义元层仓库）启动 `claude`，用 `/add-dir` 挂载 u-boot、kernel、webui 等兄弟仓库。本配置已开启 `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1`，各仓库自身的 CLAUDE.md/规则会一并载入（A1/A4）。超大单树（monorepo）参见官方专文：[Set up Claude Code in a monorepo or large codebase](https://code.claude.com/docs/en/large-codebases)（嵌套 CLAUDE.md、稀疏 worktree、按包技能）。

### 9.2 根 CLAUDE.md 模板（置于主仓根目录，按实际项目改写）

模板遵循官方写法要求：单文件控制在 200 行内、规则具体到可验证（"执行 `<测试命令>`"而非"做好测试"）、按主题拆分时使用 `.claude/rules/*.md` 或 `@path` 导入。规则是"上下文"而非强制执行——需硬拦截的动作应使用 deny 规则或 PreToolUse hook（见 10.6）。

- 来源：[Claude Code – Memory（<200 行、具体可验证、rules 目录、context not enforced configuration）](https://code.claude.com/docs/en/memory)、[Z.AI – Memory-mechanism（分层记忆与规则拆分）](https://docs.z.ai/devpack/resources/memory-mechanism)

```markdown
# 工程语境
- 本工作区为 BMC 固件全栈：Yocto/bitbake 元层、u-boot、Linux 内核（I2C/IPMB/KCS/MCTP 驱动）、
  phosphor-* D-Bus 服务、bmcweb（Redfish）、webui-vue 前端。
- 目标机型/SoC：<填写>；交叉工具链：<填写>；构建入口：<bitbake 命令/脚本>。

# 硬性约束（违反即返工）
1. 协议字段、寄存器位、D-Bus 接口签名：必须先读到对应规范文本或现有代码定义再落笔，
   禁止凭记忆书写。Redfish 资源以 DSP0266 及 bmcweb 现有 schema 为准；IPMI 命令以规范文档
   和现有 handler 为准。引用时注明文件路径与行号。
2. 内存与实时性：守护进程禁止在热路径引入动态分配与阻塞 I/O；新增依赖必须评估镜像体积。
3. 禁改区：vendor blob、签名/安全启动密钥与流程、许可证头。涉及许可证边界的复制必须停下说明。
4. 每次代码改动后必须依次执行：<格式化命令>、<静态检查命令>、<单元测试命令>；
   跨组件改动必须完成 <QEMU/仿真运行命令> 冒烟。任何一步失败不得宣布完成。
5. commit 边界：一个逻辑变更一个 commit；禁止顺手重构无关代码。

# 长任务规程
- 阶段性结论（架构判断、影响面清单、风险点）写入 docs/worklog/<日期>-<主题>.md 后再继续，
  确保上下文压缩后证据仍在磁盘上。
- 小时级构建用后台方式运行，期间继续推进可并行的工作。

# 检索优先级
上游/开源参考：优先用 zread 工具读 GitHub 仓库结构与源码；网页文档用 web-reader 取全文。
```

### 9.3 任务下达范式

GLM 官方推荐的用法范式本身即为该场景设计（项目级接管、长程重构、生产级规范压力测试）：先"技术审计"（架构图、模块职责、API 契约、数据流、调用链、技术债、约束清单），再下达带边界的改造任务，并以 `/goal` 设定收尾条件使模型持续工作直到验证通过。

每个任务的下达遵循 Z.AI 官方最佳实践的四要素结构——**Goal（要做成什么）/ Context（涉及哪些文件、报错、文档）/ Constraints（工程约束）/ Done when（怎样算完成）**。长期性规则进 CLAUDE.md，临时性指令进提示词，二者不混放。

- 来源：[Z.AI – GLM-5.2（Usage：Project-Level Codebase Takeover / Long-Horizon Refactoring / Production-Grade Standards Stress Test）](https://docs.z.ai/guides/llm/glm-5.2)、[Z.AI – Best Practice（Structure Task Inputs 四要素、"temporary instructions in the prompt, long-lived rules in configuration files"）](https://docs.z.ai/devpack/resources/best-practice)

### 9.4 证据落盘规程（对冲压缩损失）

1M 窗口极难占满，但多日任务终会触顶。规程：**阶段结论必须写入文件**（worklog、影响面清单、决策记录）。压缩摘要会替换对话史，但磁盘文件永久保留，模型可随时重读——这是"最完整上下文证据"的正确实现方式：证据的持久层在文件系统，不在对话窗口。

### 9.5 并行编排

- **计划先行**：大改动先 Shift+Tab 进入 plan 模式出计划，`ExitPlanMode` 未放行，计划必经人工审批（A4 人工闸门）。
- **worktree 隔离**：并行修改多分支时让 Claude 使用 worktree（默认 `.claude/worktrees/` 路径下创建/进入不弹窗），互不污染。
- **批量审计/迁移使用动态工作流**：workflow 是"计划写入脚本"的重型编排——阶段化、可并行、可对抗互验、可保存复跑，官方定位即"codebase audits、large migrations、cross-checked research"，单次可并行调度几十上百个子代理（本配置上限已提高至 1000）。触发方式三种：提示词包含 `ultracode` 关键词（单次）、直接指示"用 workflow 并行审计全部 phosphor-* 服务的 XX 用法"、或 `/effort ultracode` 使本会话对每个有分量的任务自动编排（锁定档为 `xhigh`，该通道处于可用状态）。fork 型子代理用于"带完整上下文的方案对比"。
- **workflow 的两条边界**：① `ultracode` 关键词与"用 workflow"的自然语言请求**仅在人工输入**（交互输入框、IDE 面板、Remote Control、标记 human 的 SDK 输入）时触发；经 `-p` 传入的提示词、计划任务提示词、webhook 一律**不触发**——无人值守需要 workflow 时，使用启动参数 `claude --effort ultracode -p "..."`（见 10.5）。② workflow 子代理**强制 `acceptEdits` + 继承 allowlist，不继承 bypass**——本配置 18 条 allow 已覆盖其全部所需（7.9）。
- **多实例协作**：agent teams 已启用，适合"一人主控 + 多队友分模块"的大迁移。
- **研究型工作流的检索指定**：内置 `/deep-research` 工作流依赖内置 WebSearch 工具（网关下不可用）。让 Claude 编写研究工作流时，应明确指定"检索用 `web-search-prime`、读页用 `web-reader`"。

- 来源：[Claude Code – Workflows（定位、规模、adversarial review、ultracode 触发、`/deep-research` 依赖 WebSearch）](https://code.claude.com/docs/en/workflows)、[Claude Code – Tools reference（EnterWorktree/Agent/Workflow 行为）](https://code.claude.com/docs/en/tools-reference)、[Claude Code – env-vars（子代理与团队相关变量）](https://code.claude.com/docs/en/env-vars)

## 10. 场景 ②：A 股深度行情分析

### 10.1 总原则

LLM 在金融数据上的唯一可靠形态是**编排器**而非数据库：它负责取数、编写代码计算、交叉验证、组织论证；数字本身必须全部来自工具调用。以下规程将这一点制度化。

### 10.2 数据铁律（写入 CLAUDE.md，同时也是验收结论的标准）

1. **零记忆数字**：任何行情/财务/宏观数字，禁止直接引用模型记忆；必须来自当轮工具调用（本地数据接口或 MCP 检索），并标注「来源（接口名或 URL）+ 获取时间」。
2. **计算全部落代码**：均线、波动率、估值分位、组合归因等一律由 Python 代码算出（Bash/PowerShell 工具执行），模型不做心算——采样随机性不影响 `pandas` 的输出，这才是"数值绝对可靠"的机制保证（也是第 8 章不调整 temperature 的底气）。
3. **双源交叉**：进入结论的关键数字（收盘价、涨跌幅、成交额、财务科目）至少两个独立来源核对；不一致时必须报告差异与取舍理由。
4. **来源分级**：交易所与法定披露渠道（上交所/深交所官网、巨潮资讯网、中国结算、央行/统计局/证监会）> 结构化数据接口（如 akshare/tushare/baostock 等本地库）> 财经媒体/聚合站。级别低的来源只能佐证，不能独立支撑结论。
5. **有损工具不入账**：WebFetch 是"小模型抽取"的有损设计（官方明示 lossy by design；本配置已将抽取模型升至 GLM-5.2，但仍是单遍抽取）——关键数字取证使用 **web-reader MCP 全文** 或 Bash 中 `curl`/`python requests` 获取原始页面，WebFetch 仅用于泛读。
6. **搜索走 web-search-prime**：内置 WebSearch 在网关下不可用；时效信息（政策、公告、突发）一律 `web-search-prime` 检索 + `web-reader` 取全文。
7. **图表证据走 Vision MCP**：`analyze_data_visualization` 读取 K 线/仪表盘，`extract_text_from_screenshot` 提取研报截图数字，避免人工转录误差。

- 来源：[Claude Code – Tools reference（WebFetch lossy by design、WebSearch 后端说明）](https://code.claude.com/docs/en/tools-reference)、[Z.AI – 四个 MCP 文档（见第 11 章）](https://docs.z.ai/devpack/overview)

### 10.3 A 股 CLAUDE.md 模板（置于分析工作区根目录）

```markdown
# 角色与目标
你是 A 股市场分析工程师：负责取数、验证、计算、组织多空论证，产出可审计的分析报告。

# 数据铁律（不可违反）
1. 任何数字必须来自本轮工具调用，标注来源与获取时间；禁止凭记忆给数。
2. 一切计算写 Python 执行（pandas），禁止心算；脚本与中间数据落盘到 data/ 与 scripts/。
3. 关键数字双源交叉验证；不一致必须披露差异及取舍理由。
4. 数据不可得就明说"取不到"，禁止估计值冒充实际值。

# 口径声明（每份报告开头必须给出）
- 数据截止时间（Asia/Shanghai）；行情快照 vs 收盘数据。
- 复权方式：前复权/后复权/不复权（涉及跨期比较必须声明）。
- 单位统一声明：元/万元/亿元；成交额与市值单位分开写清。
- 财务数据：报告期（如 2026Q1）与公告日期分开标注；同比/环比基期写明。
- 指数/板块口径：指数代码与编制方（中证/国证/申万行业版本）。

# 交易规则常识（计算与回测必须内建）
- T+1；交易日历以交易所公布为准（节假日、临时休市）。
- 涨跌停：主板 ±10%，ST/*ST ±5%，创业板/科创板 ±20%，北交所 ±30%；
  新股/次新与退市整理期规则特殊，单独核对后再用。
- 停复牌、退市、ST 变更影响可交易性与连续性：回看历史用时点数据（point-in-time），
  防幸存者偏差；禁止用后来发生的事解释之前的价格。

# 全面性检查清单（深度分析必须逐项过）
宏观与政策 / 行业景气与产业链上下游 / 公司基本面（财报三表+关键科目异动）/
资金面（成交、换手、大宗、股东户数、北向及融资融券如可得）/ 估值（绝对+相对+历史分位）/
情绪与预期差 / 风险与反方论证（必须主动检索做空/看空观点并回应）/ 结论的可证伪条件。

# 输出规范
- 报告落盘 reports/<日期>-<主题>.md；附数据来源清单表（数值|来源|获取时间|校验源）。
- 明确区分「事实（带来源）」「推断（带逻辑链）」「观点（带置信度与前提）」。
- 本工作区只做研究分析，不接实盘下单接口。
```

### 10.4 深度与全面性的执行手段

- `reasoning_effort=max` 已锁定（7.3 的 xhigh 经 Z.AI 映射即 max），无需在提示词中要求"深度思考"。
- 全面性依靠**结构**而非"多想想"：要求模型按 10.3 检查清单逐项核对，并使用 fork/子代理并行核查——例如"fork 两支分别构建多头与空头最强论证，主线汇总裁决"（fork 继承完整上下文，证据不丢失，见 7.10）。
- **重大专题使用对抗互验工作流**：workflow 的官方设计即包含 "independent agents adversarially review each other's findings before they're reported"（独立代理互相对抗审查后才汇报）——对"某行业景气拐点是否成立"这类命题，指示"用 workflow：多角度分头取证 → 交叉互验 → 汇总裁决，检索一律用 web-search-prime、读页用 web-reader"，较单线程结论具有显著更高的可信度。
- 每份报告强制设"反方论证"章节：主动用 web-search-prime 检索看空/风险观点并逐条回应，纠正单边倾向。
- **自备金融数据 MCP 置于项目级**：若另行接入行情/资讯类 MCP（如 akshare、wind、ifind、china-news 等本地封装），其 allow 规则应放入**分析工作区的** `.claude/settings.json`（如 `"mcp__akshare"`），不进入全局用户级——部署后才放行、重装不残留；全局仅对齐 Z.AI 套餐四件套这一稳定基线。

- 来源：[Claude Code – Workflows（adversarial review 模式）](https://code.claude.com/docs/en/workflows)、[Claude Code – Permissions（作用域合并）](https://code.claude.com/docs/en/permissions)

### 10.5 持续稳定复跑（盘后例行）——双轨制

无人值守采用 **Windows 任务计划程序 + headless 模式**，按任务性质分两轨：

```powershell
# 轨道一：每日例行（结构稳定、可比对、可复跑——B5 主力）
claude -p "执行每日例行分析：按 CLAUDE.md 铁律更新自选池数据、运行 scripts/daily.py、生成 reports/$(Get-Date -Format yyyy-MM-dd)-daily.md，全部数字附来源清单"

# 轨道二：重大专题（季度策略复盘、行业景气拐点判定——大规模并行深挖 + 对抗互验）
claude --effort ultracode -p "对 <标的/行业> 做深度多空核查：多角度分头取证、交叉互验后汇总裁决；检索一律用 web-search-prime、读页用 web-reader；产出 reports/$(Get-Date -Format yyyy-MM-dd)-deep.md，全部数字附来源清单"
```

双轨的划分依据是**产物性质**，而非节省配额：每日例行的价值在于结构稳定、日间可比、异常可归因——固定脚本 + 单线程 xhigh 是其正确形态；workflow 的编排自由度（每次并行结构均由脚本现场生成）用于例行任务反而引入日间不可比性，它属于重大专题。配额仅为可用性约束：触及上限时按第 12 章切换账号。

三个 headless 关键机制（均已在本配置内置或说明）：

1. **`ultracode` 关键词在 `-p` 提示词中不生效**（官方：关键词仅对人工输入的 prompt 生效），因此轨道二必须使用 `--effort ultracode` 启动参数（需 v2.1.203+），使整个会话对每个有分量的任务自动编排 workflow。
2. **`CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0`（settings 已内置）**：headless 默认仅等待后台子代理/workflow 10 分钟，超时直接终止剩余任务并退出——轨道二的深度 workflow 极易超过 10 分钟，不设 `0` 即为最隐蔽的"无人值守被截断"。
3. workflow 子代理在 headless 下无人可询问：不在 allowlist 的调用被直接拒绝（而非弹窗）——本配置 18 条 allow 已覆盖（7.9）。

其余要点不变：`-p` 沿用同一份用户级 settings（bypass、重试看门狗、MCP 全部生效）；产物落盘 = 审计底稿；`cleanupPeriodDays=365` 保留转录一年；会话内轻量轮询另有 `/loop`。

- 来源：[Claude Code – Workflows（关键词仅限人工输入、`--effort ultracode`、acceptEdits 语义、headless 无交互确认）](https://code.claude.com/docs/en/workflows)、[Claude Code – env-vars（`CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS`、`CLAUDE_CODE_RETRY_WATCHDOG`）](https://code.claude.com/docs/en/env-vars)、[Claude Code – Overview（headless/`-p`、`/loop`）](https://code.claude.com/docs/en/overview)

### 10.6 实盘边界（唯一建议保留的硬闸）

分析与执行必须物理分离：实盘下单脚本置于独立仓库，在**该仓库**的 `.claude/settings.local.json` 中添加窄 deny（如 `"Bash(python live_trade.py*)"`、`"Edit(//C/trading/keys/**)"`）。deny 规则在包括 bypass 在内的一切模式下生效，是官方提供的唯一硬闸；分析工作区保持零 deny 全自动。

- 来源：[Claude Code – Permissions（deny 全模式生效、路径规则语法）](https://code.claude.com/docs/en/permissions)

---

# 第四部分：运维

## 11. Coding Plan 专属 MCP 部署

四个专属 MCP 是 Coding Plan 的套餐能力。MAX 档配额：Web Search + Web Reader + Zread **共享每月 4000 次**；Vision 走套餐 5 小时 prompt 资源池。配额用尽仅暂停 MCP，不扣除余额；多账号下按第 12 章切换账号即恢复。

- 来源：[Z.AI – Coding Plan Overview（Exclusive MCP / MCP Usage Limits）](https://docs.z.ai/devpack/overview)、[Z.AI – FAQ](https://docs.z.ai/devpack/faq)

### 11.0 部署须知（Windows）

- `-s user` 表示用户作用域：写入 `%USERPROFILE%\.claude.json`（MCP 的用户/本地作用域存储于此，**而非** settings.json），全项目生效；项目作用域写入 `.mcp.json`。
- Vision 是本地 stdio 服务器（npx 拉起 Node 进程，要求 **Node.js ≥ 22**）；其余三个为远程 HTTP 服务器，零本地依赖。
- 亦可使用官方交互助手一次性配置：`npx @z_ai/coding-helper`（Node ≥ 18）。
- 来源：[Claude Code – MCP（installation scopes）](https://code.claude.com/docs/en/mcp)、[Z.AI – Coding Tool Helper](https://docs.z.ai/devpack/extension/coding-tool-helper)

### 11.1 Vision MCP（视觉理解，本地 stdio）

后端 GLM-4.6V。工具：`ui_to_artifact`、`extract_text_from_screenshot`、`diagnose_error_screenshot`、`understand_technical_diagram`、`analyze_data_visualization`、`ui_diff_check`、`image_analysis`、`video_analysis`（≤8MB MP4/MOV/M4V）。

```powershell
claude mcp add -s user zai-mcp-server --env Z_AI_API_KEY=your_api_key --env Z_AI_MODE=ZAI -- npx -y "@z_ai/mcp-server@latest"
```

手动配置（`%USERPROFILE%\.claude.json` 的 `mcpServers`）：

```json
{
  "mcpServers": {
    "zai-mcp-server": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@z_ai/mcp-server@latest"],
      "env": { "Z_AI_API_KEY": "your_api_key", "Z_AI_MODE": "ZAI" }
    }
  }
}
```

要点：官方要求 ≥ 0.1.2 版本才具备 GLM-4.6V 能力，`@latest` 防止 npx 缓存旧版（官方提示）；用法是将图片放入项目目录后在对话中点名（粘贴图片走模型接口而非该 MCP）；排障先裸跑 `$env:Z_AI_API_KEY="your_api_key"; npx -y @z_ai/mcp-server`，connection closed 先检查 `node -v` ≥ 22。

- 来源：[Z.AI – Vision MCP Server](https://docs.z.ai/devpack/mcp/vision-mcp-server)

### 11.2 Web Search MCP（实时检索，远程 HTTP）

工具：`webSearchPrime`（标题、URL、摘要、站点名等）。A 股时效信息主入口，兼替代不可用的内置 WebSearch。

```powershell
claude mcp add -s user -t http web-search-prime https://api.z.ai/api/mcp/web_search_prime/mcp --header "Authorization: Bearer your_api_key"
```

```json
{
  "mcpServers": {
    "web-search-prime": {
      "type": "http",
      "url": "https://api.z.ai/api/mcp/web_search_prime/mcp",
      "headers": { "Authorization": "Bearer your_api_key" }
    }
  }
}
```

- 来源：[Z.AI – Web Search MCP Server](https://docs.z.ai/devpack/mcp/search-mcp-server)

### 11.3 Web Reader MCP（网页全文，远程 HTTP）

工具：`webReader`（标题、正文、元数据、链接列表）。取证级网页读取（公告全文、官方文档），与有损的 WebFetch 分工（10.2 第 5 条）。

```powershell
claude mcp add -s user -t http web-reader https://api.z.ai/api/mcp/web_reader/mcp --header "Authorization: Bearer your_api_key"
```

```json
{
  "mcpServers": {
    "web-reader": {
      "type": "http",
      "url": "https://api.z.ai/api/mcp/web_reader/mcp",
      "headers": { "Authorization": "Bearer your_api_key" }
    }
  }
}
```

- 来源：[Z.AI – Web Reader MCP Server](https://docs.z.ai/devpack/mcp/reader-mcp-server)

### 11.4 Zread MCP（GitHub 仓库理解，远程 HTTP）

工具：`search_doc`、`get_repo_structure`、`read_file`。读取 OpenBMC/内核等上游仓库、评估开源依赖、跟踪上游 issue 的主力（仅限公开仓库）。

```powershell
claude mcp add -s user -t http zread https://api.z.ai/api/mcp/zread/mcp --header "Authorization: Bearer your_api_key"
```

```json
{
  "mcpServers": {
    "zread": {
      "type": "http",
      "url": "https://api.z.ai/api/mcp/zread/mcp",
      "headers": { "Authorization": "Bearer your_api_key" }
    }
  }
}
```

- 来源：[Z.AI – Zread MCP Server](https://docs.z.ai/devpack/mcp/zread-mcp-server)

### 11.5 部署后验证

`claude mcp list` 应显示四个 connected；会话内 `/mcp` 可见完整工具名。settings.json 已配套：四服务器 allow 放行、`MAX_MCP_OUTPUT_TOKENS=50000`、`MCP_TIMEOUT=120000`。服务器名与 allow 规则必须一致（`zai-mcp-server`/`web-search-prime`/`web-reader`/`zread`），改名需同步修改 `mcp__<server>` 规则。

- 来源：[Claude Code – MCP（Managing your servers）](https://code.claude.com/docs/en/mcp)

## 12. 多账号轮换（可用性机制）

多个 MAX 账号在本方案中的定位：**可用性冗余**。即便 MAX 档，仍存在 5 小时窗口与周配额上限（约 1600 prompts/5h、8000/周），触顶时切换账号续跑是唯一不降级的路径（不换模型、不降低 effort）。

1. **直接更换 Key**：修改 settings.json 的 `ANTHROPIC_AUTH_TOKEN`。`env` 块热加载，通常无需重启。
2. **每账号一个配置目录（推荐）**：`CLAUDE_CONFIG_DIR` 整体切换配置根（官方明示用于 "running multiple accounts side by side"）：`$env:CLAUDE_CONFIG_DIR="$env:USERPROFILE\.claude-acc2"; claude`。每个目录放置同一份 settings.json（仅 Key 不同）；MCP 注册存储于各目录的 `.claude.json`，新目录需重新执行第 11 章的 `claude mcp add`。
3. **apiKeyHelper 自动轮换**：`apiKeyHelper` 指向返回当前可用 Key 的脚本（`CLAUDE_CODE_API_KEY_HELPER_TTL_MS` 控制刷新间隔），实现触顶自动切换账号；采用此方式时应将 `ANTHROPIC_AUTH_TOKEN` 从 `env` 移除，避免两套认证机制冲突。

注意：切换账号 = 切换 Z.AI 侧缓存主体，新账号首轮全量冷启动（无损，仅慢一轮），应尽量在任务边界切换；Z.AI 政策禁止的是"账号共享/多用户使用"，同一使用者持有多份订阅进行轮换不属此列，但需关注政策更新。

- 来源：[Z.AI – Coding Plan Overview（配额表）](https://docs.z.ai/devpack/overview)、[Claude Code – env-vars（`CLAUDE_CONFIG_DIR`、`CLAUDE_CODE_API_KEY_HELPER_TTL_MS`）](https://code.claude.com/docs/en/env-vars)、[Claude Code – Settings（`apiKeyHelper`）](https://code.claude.com/docs/en/settings)、[Z.AI – Usage Policy](https://docs.z.ai/devpack/usage-policy)

## 13. 升级 SOP

自动更新已被 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` 关闭，升级完全由使用者主动执行：

1. **确认无任务运行**（升级 = 系统提示词变化 = 行为漂移 + 缓存冷启动，只能发生在任务间隙——A6）。
2. 连接 VPN → `claude --version` 记录当前版本。
3. 升级（按安装方式）：原生安装 `claude update`；WinGet `winget upgrade Anthropic.ClaudeCode`；npm `npm install -g @anthropic-ai/claude-code@latest`。
4. `claude --version` + `claude doctor` 验证。
5. 断开 VPN，正常使用（模型流量仅走 `api.z.ai`）。
6. 升级后**从新会话开始新任务**；避免立即 `--resume` 长会话（官方明示：升级后恢复会话将无缓存重放全部历史，且新系统提示下的行为与原任务存在漂移）。

- 来源：[Claude Code – Overview（各安装方式更新行为）](https://code.claude.com/docs/en/overview)、[Claude Code – Prompt caching（Upgrading Claude Code）](https://code.claude.com/docs/en/prompt-caching)

## 14. 一致性管理：任务中途的行为漂移源清单

以下操作会在任务中途改变"回答者的条件"（缓存重建只是其可观测的影子），**任务进行中一律避免**，统一移至任务边界执行：

| 漂移源 | 后果 | 对策 |
| --- | --- | --- |
| `/model` 切换模型 | 不同模型 = 不同回答者 | 本配置为全 5.2 单模型，选单中已无备选；不得手动指定其他模型 |
| `/effort` 切换档位 | 推理深度改变（Claude Code 会弹出确认框） | 已用环境变量锁定 xhigh（经映射即 max），`/effort` 实际失效 |
| 升级 Claude Code | 系统提示词/工具定义变化 | 第 13 章 SOP：仅在任务间隙升级 |
| MCP 服务器中途连接/断开 | 工具定义集合变化 | 四个 MCP 一次配置完成不再变动；服务器抖动由 `MCP_TIMEOUT` 与重连机制吸收 |
| 以裸工具名 deny 工具 | 工具集合变化 | deny 保持为空（第 7.9） |
| `/compact` 压缩 | 对话史被摘要替换 | 手动压缩安排在任务之间；证据按 9.4/10.5 规程落盘 |
| 中途修改 CLAUDE.md | 本会话不生效（下次 `/clear`/重启才生效），易产生"以为已修改"的错觉 | 修改规则后重启会话再开工 |

无漂移风险、可随时执行：编辑仓库文件、Shift+Tab 切换权限模式、调用技能/命令、`/recap`、`/rewind`、派生子代理。

观测手段（按需使用、无常驻组件）：`/status` 查看模型与设置来源、`/context` 查看窗口占用与压缩水位、`/effort` 确认档位被环境变量接管；缓存读写可在 Z.AI 侧响应的 `usage.prompt_tokens_details.cached_tokens` 观察。本配置无常驻状态栏组件——漂移的结构性来源已在配置层消除（见上表对策），如需临时观测，可使用官方 `/statusline` 命令按需生成。

- 来源：[Claude Code – Prompt caching（cache 字段含义）](https://code.claude.com/docs/en/prompt-caching)、[Claude Code – Statusline（`/statusline` 命令）](https://code.claude.com/docs/en/statusline)、[Z.AI – Context Caching](https://docs.z.ai/guides/capabilities/cache)

## 15. 部署后验证清单

| # | 动作 | 期望结果 |
| --- | --- | --- |
| 1 | `claude --version` | ≥ v2.1.212（全部版本门槛见第 17 章） |
| 2 | 启动 `claude` | 无认证报错；`⏵⏵ bypass permissions on` 徽标 |
| 3 | `/status` | Setting sources 含 User settings；Model 为 `glm-5.2[1m]`（显示名 GLM-5.2 (1M)） |
| 4 | `/model` | 各别名位均显示 GLM-5.2；**无**任何 4.7/turbo 备选项 |
| 5 | `/effort` | 提示档位被环境变量接管（xhigh） |
| 6 | `/context` | 窗口按 1M 计 |
| 7 | 复杂提问 | 思考过程可见（`Ctrl+O`），流式稳定 |
| 8 | `claude mcp list` | 四个 MCP 全部 connected |
| 9 | "搜索今天沪深两市成交额并给来源" | 走 `web-search-prime`+`web-reader`，无权限弹窗，数字带来源与时间 |
| 10 | 用 `web-reader` 拉取长页面（如一份完整年报页） | 全文返回，不被 60 秒/5 分钟截断 |
| 11 | 项目中放置 K 线截图，"分析 chart.png" | 走 `zai-mcp-server` 视觉工具 |
| 12 | 提示词包含 `ultracode` 下达审计任务 | 触发 workflow 编排，`/workflows` 可见并行子代理 |
| 13 | Shift+Tab | manual → acceptEdits → plan → bypass 循环 |
| 14 | 日常断开 Anthropic 访问 | 无升级/遥测报错刷屏；WebFetch 可用（预检已跳过） |

## 16. 故障排查速查表

| 症状 | 原因 | 处置 |
| --- | --- | --- |
| `1113 Insufficient Balance` / 扣除账户余额 | Base URL 错误（走了普通 API 端点）或模型名不在允许列表 | 核对 `https://api.z.ai/api/anthropic` 与 glm-5.2；[Z.AI FAQ](https://docs.z.ai/devpack/faq) |
| `glm-5.2[1m]` 模型不存在 | CLI 版本过旧 | VPN 下升级；[Z.AI – 切换模型](https://docs.z.ai/devpack/latest-model) |
| 修改 settings 不生效 | JSON 语法错误/文件位置错误/旧窗口 | 全部关闭重开；`/status` 查看 sources；`claude doctor`；[Z.AI – Claude Code FAQ](https://docs.z.ai/devpack/tool/claude) |
| 响应中途中断 | 链路抖动 | 已含重试看门狗；频发时检查本地代理是否拦截 `api.z.ai` |
| `anthropic-beta` 头报错 | 端点不识别某 beta | 临时添加 `"CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "1"`；[env-vars](https://code.claude.com/docs/en/env-vars) |
| Vision MCP 秒断 | Node<22 / npx 缓存旧版 / Key 未配置 | `node -v`；`@latest`；裸跑测试；[Vision MCP](https://docs.z.ai/devpack/mcp/vision-mcp-server) |
| 三个远程 MCP 集体失效 | 当月共享 4000 次配额用尽或 Key 失效 | 控制台查用量；切换账号或等待下月；[Overview](https://docs.z.ai/devpack/overview) |
| "忘记前文" | 提前压缩或窗口按 200K 误判 | `/context` 核对；确认 `CLAUDE_CODE_AUTO_COMPACT_WINDOW`/`[1m]` 生效 |
| WebFetch 全部失败 | 未跳过 Anthropic 预检 | `skipWebFetchPreflight: true`；[Settings](https://code.claude.com/docs/en/settings) |
| 内置 WebSearch 报错 | Anthropic 服务端工具，网关不可用 | 使用 web-search-prime；[Tools reference](https://code.claude.com/docs/en/tools-reference) |
| 非 bypass 模式弹出权限窗 | 工具不在 allow / 拼写非权威名 | 对照 7.9 清单；`/permissions` 查看规则来源 |
| 5 小时窗口触顶 | MAX 档亦有窗口配额 | 按第 12 章切换账号，任务不降级续跑 |
| 后台子代理异常标记 "failed" | 长命令期间无进度事件被判失速 | 已放宽到 1h；超过 1h 的构建改用后台命令执行；[env-vars（`CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS`）](https://code.claude.com/docs/en/env-vars) |
| `/effort` 未提示被环境变量接管 / 疑似 effort 未生效 | 能力声明或 `CLAUDE_CODE_ALWAYS_ENABLE_EFFORT` 未生效 | 核对 `_SUPPORTED_CAPABILITIES` 与 `CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1`；重启会话；`/status` 查看设置来源 |
| 无人值守的深度分析 10 分钟被终止 | headless 后台等待上限默认 10 分钟 | 本配置已设 `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0`（无限等待）；核对 `/status` 设置来源；[env-vars](https://code.claude.com/docs/en/env-vars) |
| `-p` 提示词中写了 ultracode 却没有 workflow | 关键词仅对人工输入生效 | 使用 `claude --effort ultracode -p`（10.5 轨道二）；[Workflows](https://code.claude.com/docs/en/workflows) |
| `ultracode` 不触发 workflow | 锁定档不是 `xhigh`，或 workflows 被关闭 | 确认 `CLAUDE_CODE_EFFORT_LEVEL=xhigh`（见 7.3）；确认未设 `disableWorkflows`；[Workflows](https://code.claude.com/docs/en/workflows) |

---

# 第五部分：附录

## 17. 版本门槛备查表

以下增强项存在最低 CLI 版本门槛，旧版本会静默失效，用于排查增强项未生效的情形：



| 变量（本配置值） | 最低版本 | 旧版行为 |
| --- | --- | --- |
| `CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION=1000` | v2.1.212 | 静默回退 200 |
| `CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS=0` | v2.1.212 | 静默回退 2 分钟自动转后台 |
| `CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT=600000` | v2.1.187 | 走传输层默认（网络 5 分钟/stdio 30 分钟） |
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS` 对自定义模型名直接生效 | v2.1.193 | 需配合其他条件 |
| `CLAUDE_CODE_RETRY_WATCHDOG=1` | v2.1.186 | 无看门狗语义，按默认重试 |
| `--effort ultracode` 启动参数 | v2.1.203 | 报 Unknown value（会话内 `/effort ultracode` 不受此限） |

第 13 章的升级纪律（保持最新 CLI）本身即是对这张表的最佳防御。`claude --version` ≥ v2.1.212 即全部满足。
## 18. 参考链接汇总

**Claude Code 官方文档**

- 总览与安装：<https://code.claude.com/docs/en/overview>
- 设置全参考：<https://code.claude.com/docs/en/settings>
- 环境变量全参考：<https://code.claude.com/docs/en/env-vars>
- 模型配置（别名/[1m]/effort/能力声明/回退链）：<https://code.claude.com/docs/en/model-config>
- 权限系统：<https://code.claude.com/docs/en/permissions>
- 权限模式（Shift+Tab）：<https://code.claude.com/docs/en/permission-modes>
- 工具参考（权威工具名/行为/上限）：<https://code.claude.com/docs/en/tools-reference>
- 提示缓存机制：<https://code.claude.com/docs/en/prompt-caching>
- MCP 接入与作用域：<https://code.claude.com/docs/en/mcp>
- 动态工作流（workflow/ultracode）：<https://code.claude.com/docs/en/workflows>
- 状态栏（statusline 字段与 Windows 配置）：<https://code.claude.com/docs/en/statusline>
- 记忆机制（CLAUDE.md/规则/auto memory）：<https://code.claude.com/docs/en/memory>
- 超大代码库/monorepo 专文：<https://code.claude.com/docs/en/large-codebases>

**Z.AI 官方文档**

- 开发者文档首页：<https://docs.z.ai>
- Coding Plan 总览（配额/倍率/专属 MCP）：<https://docs.z.ai/devpack/overview>
- 快速开始（端点表）：<https://docs.z.ai/devpack/quick-start>
- Claude Code 接入：<https://docs.z.ai/devpack/tool/claude>
- 切换 GLM-5.2 / 1M / effort 映射：<https://docs.z.ai/devpack/latest-model>
- FAQ（端点/允许模型/倍率）：<https://docs.z.ai/devpack/faq>
- 使用政策（并发/账号规则）：<https://docs.z.ai/devpack/usage-policy>
- Vision MCP：<https://docs.z.ai/devpack/mcp/vision-mcp-server>
- Web Search MCP：<https://docs.z.ai/devpack/mcp/search-mcp-server>
- Web Reader MCP：<https://docs.z.ai/devpack/mcp/reader-mcp-server>
- Zread MCP：<https://docs.z.ai/devpack/mcp/zread-mcp-server>
- Coding Tool Helper：<https://docs.z.ai/devpack/extension/coding-tool-helper>
- GLM-5.2 模型页（场景用法范式）：<https://docs.z.ai/guides/llm/glm-5.2>
- GLM-5.2 迁移指南（采样默认值/1M/128K/reasoning_effort）：<https://docs.z.ai/guides/overview/migrate-to-glm-new>
- Coding Agent 最佳实践（任务四要素/计划先行/技能与自动化）：<https://docs.z.ai/devpack/resources/best-practice>
- 记忆机制（分层记忆/规则拆分）：<https://docs.z.ai/devpack/resources/memory-mechanism>
- 深度思考（thinking/reasoning_effort）：<https://docs.z.ai/guides/capabilities/thinking>
- 思考模式（Interleaved/Preserved/Turn-level）：<https://docs.z.ai/guides/capabilities/thinking-mode>
- 上下文缓存：<https://docs.z.ai/guides/capabilities/cache>
- 核心参数（max_tokens/temperature/top_p）：<https://docs.z.ai/guides/overview/concept-param>

> 领域作业规程说明：第 9、10 章中 BMC 工程实践与 A 股交易规则/口径清单（T+1、分板块涨跌停幅度、复权、报告期 vs 公告日、point-in-time 等）为领域专家经验层，不出自上述两个文档站；使用前请按实际标的与最新交易所规则校验（新股、退市整理期等特殊证券的规则随监管调整）。
