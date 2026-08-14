# GLM-5.3 × Claude Code（Windows）配置与作业手册

> **定位**：本手册面向两个生产场景——**① BMC 级超大复杂代码体系开发**（从嵌入式底层到上层 Web 的全栈工程）与 **② A 股市场持续深度行情分析**（数据值绝对可靠、考虑问题全面、可长期稳定复跑）。
>
> **总原则**：成本与速度不纳入决策考量。所有决策仅对三项指标负责：**正确性、完备性、可靠性**。凡"节省 token / 节省配额 / 提升速度"与"更准确 / 更完整 / 更稳定"相冲突之处，一律选择后者。全链路仅允许一个模型：**GLM-5.3**——包括后台辅助任务在内，不存在任何降级路径。
>
> **适用环境**：Windows 原生 Claude Code CLI（2026-08 时点 v2.1.x）+ Z.AI GLM Coding Plan MAX（多账号轮换）。
> **文档快照日期**：2026-08-28。全部机制性结论以两个官方文档站为准：[Claude Code Docs](https://code.claude.com/docs/en/overview)、[Z.AI Docs](https://docs.z.ai)；长上下文质量结论以第 7.4 节所引权威研究（Anthropic 工程博客、Chroma、ICML/COLM 论文）为准；两大领域的作业规程（第 9、10 章）为专家经验层，独立于上述文档。

---

## 目录

- **第一部分：需求定调**
  - 1. 场景需求规格（由两大场景反推的硬性需求）
  - 2. 对"高缓存命中"的定调
  - 3. 模型策略：主线单旗舰 + 多模态专线
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
  - 11. 多模态证据作业手册（vision 子代理）与专属 MCP 部署
  - 12. 多账号轮换（可用性机制，而非节省手段）
  - 13. 升级 SOP
  - 14. 一致性管理：任务中途的行为漂移源清单
  - 15. 部署后验证清单
  - 16. 故障排查速查表
- **第五部分：附录**
  - 17. GLM-5.3 迁移说明与版本门槛
  - 18. 参考链接汇总

---

# 第一部分：需求定调

## 1. 场景需求规格

最深思考、最完整上下文、最少截断、最高缓存命中是方向性目标，并非可直接执行的需求。本章将两个场景加一条两场景共用的多模态证据链分解为**可验证、可映射到配置项**的需求条目（编号 A1–A6 / B1–B6 / C1–C3，第 4 章给出每条需求到具体参数的追溯）。

### 1.1 场景 ①：超大复杂代码体系（以 BMC 为例）

BMC（基板管理控制器）开发是"单任务跨越整个技术栈"的典型代表：Yocto/bitbake 构建体系、u-boot、内核驱动（I2C/IPMB/KCS/MCTP）、设备树、D-Bus 服务群（OpenBMC 的 phosphor-* 仓库族）、IPMI / Redfish（DMTF DSP0266）协议服务、直至 WebUI 前端。由此反推的硬需求：

| 编号 | 需求 | 判定标准 |
| --- | --- | --- |
| **A1 跨栈上下文** | 单个任务的推理必须同时容纳多仓库、多语言（C / C++ / DTS / Python / JS）的真实代码与工程约定 | 1M 窗口全程可用**且会话永不因触顶进入不可恢复状态**（压缩水位受控，见 7.4）；多目录挂载时各仓库的 CLAUDE.md 全部载入；巨型源码树的检索不超时 |
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

### 1.3 多模态证据链（两场景共用）

BMC 侧的报错/崩溃截图、原理图与时序图、面板照片、复现录屏、PDF 规范文档（DSP0266 等），A 股侧的 K 线图、研报 PDF/扫描件、数据平台图表——大量一手证据天然是**非文本**形态，而主线模型 GLM-5.3 官方明示 "text-only inputs"（纯文本输入）。由此反推的硬需求：

| 编号 | 需求 | 判定标准 |
| --- | --- | --- |
| **C1 多模态可读** | 图片、视频、文档文件三类证据都必须能被读取并转化为文字，主线不得因收到视觉内容而报错 | 多模态链路走专用模型（GLM-5.3-Flash，GLM-5 系列首个原生多模态模型，支持图片/视频/文件输入），并**最大化承载其全部模态**——图片直读、视频抽帧读、PDF 分页读；主线收图即 400 的结构性风险被路由消除 |
| **C2 主线不妥协** | 为获得视觉能力，不得把主线或任何别名位换成次级模型 | 视觉模型不进入任何 `ANTHROPIC_DEFAULT_*_MODEL` 别名位；`/model` 选单无备选原则保持 |
| **C3 视觉可靠性** | 视觉转文字的过程本身可审计：转录先行、细节保全、不确定性明示 | vision 子代理系统提示内置作业规程（先转录后判读、抽帧/裁剪保全、看不清就明说），见第 11 章 |

## 2. 对"高缓存命中"的定调

本手册对该机制的定调如下：

1. **缓存是无损机制，与准确性零冲突**。提示缓存的本质是"逐字节精确匹配的前缀复用"——命中时服务端复用的是与重算**完全相同**的计算结果，不存在"命中缓存导致回答质量下降"的情形。因此它不需要被刻意追求，也不需要被防范：**保持默认开启即可**（关闭它不会换取任何精度，只会让每轮重算同样的内容）。
2. **本配置没有任何为缓存牺牲能力的设定**。唯一与缓存相关的参数 `CLAUDE_CODE_ATTRIBUTION_HEADER=0` 的作用是"从系统提示词开头移除客户端版本指纹块"——这是减少与任务无关的提示噪音，缓存收益属于附带效果。
3. **第 14 章"行为漂移源清单"的真正价值是一致性，而非费用**。中途切换模型、切换 effort、MCP 服务器断连、升级版本——这些操作的要害是**改变了模型的行为条件**（不同模型/档位/系统提示 = 不同的回答者），缓存重建只是其可观测的影子。该清单服务于 A6/B5，与费用无关。
4. **Z.AI 侧唯一与缓存相关且关乎精度的机制是 Preserved Thinking**（保留历史轮推理内容），官方明确其"提升模型表现"，且在 Coding Plan 端点**默认开启**、无需配置——它是精度特性，缓存命中率提升是副产品。

- 来源：[Claude Code – Prompt caching（前缀精确匹配机制）](https://code.claude.com/docs/en/prompt-caching)、[Z.AI – Thinking Mode（Preserved thinking）](https://docs.z.ai/guides/capabilities/thinking-mode)、[Claude Code – env-vars（`CLAUDE_CODE_ATTRIBUTION_HEADER`）](https://code.claude.com/docs/en/env-vars)

## 3. 模型策略：主线单旗舰 + 多模态专线

Coding Plan 端点当前提供两个 5.3 系模型：`glm-5.3`（旗舰）与 `glm-5.3-flash`。二者关键差异不在代码能力（见下表），而在**输入模态**：旗舰官方明示 "GLM-5.3 currently supports text-only inputs"（纯文本）；GLM-5.3-Flash 是 "the first native multimodal model in the GLM-5 series"（GLM-5 系列首个原生多模态模型），支持图片、视频与文件输入。规格两者一致：1M 上下文、思考不可关闭（`thinking.type` 仅支持 `enabled`）、`reasoning_effort` 默认 `max`。

**主线：全部文本推理仅用 GLM-5.3。** "复杂代码开发只能使用代码能力最强的模型"有官方基准的硬数据支撑（Z.ai 官方发布口径，自跑 harness；注意 Terminal-Bench 官方验证榜 tbench.ai 尚无 5.3 系条目，以下均为厂商自报）：

| Code Agent 基准 | GLM-5.3 | GLM-5.3-Flash | GLM-5.2 | DeepSeek-V4-Pro-0813 | Opus 4.8 |
| --- | --- | --- | --- | --- | --- |
| Terminal Bench 2.1 | **88.2** | 84.3 | 81.0 | 87.9 | 85.0 |
| Terminal Bench 3.0 | **28.3** | （未公布） | 4.6 | — | 21.1 |
| DeepSWE v1.1 | **66.9** | 63.4 | 46.2 | 62.7 | 58.0 |
| FrontierSWE | **78.1** | （未公布） | 67.5 | — | 66.5 |
| SWE-Marathon v1.1 | **42.5** | （未公布） | 19.4 | — | 48.8 |
| Agents' Last Exam | **28.5** | 26.3 | 23.8 | 25.7 | 25.7 |
| Artificial Analysis 智能指数 | **60** | 57 | 53 | ≈53 | — |

旗舰在全部已公布基准上领先；Flash 差距很小（DeepSWE 63.4 已反超 Opus 4.8），但极限长时程基准（TB3.0 / FrontierSWE / SWE-Marathon）Flash 未公布成绩——这正是"复杂代码开发用最强模型"所覆盖的地带。因此：**四个别名位全部 GLM-5.3，`/model` 选单不设任何备选**；后台辅助功能（Haiku 位：会话标题、WebFetch 内容抽取）同样采用旗舰——辅助环节不使用次级模型；`fallbackModel` 保持不设置，过载时按第 7.6 节看门狗重试同一模型，不允许静默降级出活。Flash 的代码能力足以独立承担日常开发主力（详见分支版说明），但那属于另一套配置（`glm-5.3-flash` 分支），不在本主线配置中混用——单会话内模型切换即行为漂移（A6）。

**多模态专线：flash 只存在于 vision 子代理。** 多模态输入（图片、视频、文件）是 GLM-5.3-Flash 的独占能力（旗舰收图直接 400），多模态需求使第二个模型不可避免。专线的设计原则与主线对称——**最大化利用 flash 的多模态承载**：图片直读、视频抽帧后读、PDF/文档分页读，一切非文本证据都由 flash 的视觉理解处理，全部模态最终收敛为 image 内容块这一条通道（5.3 节）；Vision MCP 仅作 flash 通道异常时的**最后兜底**（11.3）。本配置的隔离手段是结构性的：

- flash **不进入任何 `ANTHROPIC_DEFAULT_*_MODEL` 别名位**，`/model` 选单中不存在，主线不可能误切换到它；
- 它仅出现在 vision 子代理定义（`agents/vision.md`）的 `model` frontmatter 中——视觉任务在子代理的独立上下文中完成，文本结论回传主线（旗舰）；
- **`CLAUDE_CODE_SUBAGENT_MODEL` 必须保持不设置**（第 8 章）：该变量的优先级高于子代理定义的 `model` frontmatter，一旦设置，vision 子代理会被强制拉回纯文本的旗舰、读图必然 400。不设置时，常规子代理按官方默认 `inherit` 继承主会话的 GLM-5.3 (1M)，vision 子代理按 frontmatter 命中 flash——两条线各得其所。

模型矩阵——**主线四位全旗舰 + 多模态专线单点 flash，无任何备选、无任何回退**：

| Claude Code 模型位 | 值 | 承担的工作 |
| --- | --- | --- |
| Opus 位 | `glm-5.3[1m]` | 主会话（默认 `model: "opus"`） |
| Sonnet 位 | `glm-5.3[1m]` | 任何解析到 sonnet 别名的路径（含 `opusplan` 执行阶段等） |
| Fable 位 | `glm-5.3[1m]` | 误触 `/model fable` / `best` 时的兜底 |
| Haiku 位 | `glm-5.3` | 后台辅助功能（标题、WebFetch 抽取等）。注：`[1m]` 后缀官方仅对 Opus/Sonnet 位提供文档保证，Haiku 位任务本身极短，无需 1M 声明 |
| 常规子代理 | （不设 `CLAUDE_CODE_SUBAGENT_MODEL`，默认 `inherit`） | Explore、fork、workflow 代理、agent teams 队友全部继承主会话 = GLM-5.3 (1M) |
| vision 子代理 | frontmatter `model: glm-5.3-flash` | 一切非文本证据（图片/视频/PDF 文档）的唯一主通道（第 7.13、11 章） |

- 来源：[Z.AI – GLM-5.3（"text-only inputs"）](https://docs.z.ai/guides/llm/glm-5.3)、[Z.AI – GLM-5.3-Flash（原生多模态、image_url 用法）](https://docs.z.ai/guides/vlm/glm-5.3-flash)、[Z.ai – GLM-5.3 发布（旗舰基准全表）](https://z.ai/blog/glm-5.3)、[智谱开放平台 – GLM-5.3-Flash（Flash 基准与 AA 指数）](https://docs.bigmodel.cn/cn/guide/models/vlm/glm-5.3-flash)、[Z.AI – Claude Code 接入（官方示例含 `glm-5.3-flash[1m]`）](https://docs.z.ai/devpack/tool/claude)、[Claude Code – Sub-agents（`model` frontmatter 与解析优先级：环境变量 > 调用参数 > frontmatter > 继承）](https://code.claude.com/docs/en/sub-agents)、[Claude Code – Model configuration（别名机制、Fallback model chains）](https://code.claude.com/docs/en/model-config)、[Z.AI – FAQ（Coding Plan 端点允许的模型列表）](https://docs.z.ai/devpack/faq)

## 4. 需求 → 配置追溯矩阵

| 需求 | 对应配置/机制 | 详解章节 |
| --- | --- | --- |
| A1 跨栈上下文 | `glm-5.3[1m]` 全别名位、`CLAUDE_CODE_AUTO_COMPACT_WINDOW=800000`（1M 窗口 + 80% 压缩水位）、`CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000`、`CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1`、`CLAUDE_CODE_GLOB_TIMEOUT_SECONDS=60`、上下文生命周期规程 | 7.2 / 7.4 / 9.4 |
| A2 长周期执行 | `API_TIMEOUT_MS=3000000`、`API_FORCE_IDLE_TIMEOUT=0`、`CLAUDE_STREAM_IDLE_TIMEOUT_MS=1800000`、`CLAUDE_CODE_RETRY_WATCHDOG=1`、`BASH_MAX_TIMEOUT_MS=3600000`、`CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS=3600000` | 7.6 |
| A3 证据先行 | `BASH_MAX_OUTPUT_LENGTH=150000`、`TASK_MAX_OUTPUT_LENGTH=160000`、`MAX_MCP_OUTPUT_TOKENS=50000`、`CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS=65536`、Zread/Web Reader MCP | 7.5 / 11 |
| A4 规范硬约束 | CLAUDE.md 模板、验证闭环规程、（可选）项目级 deny/hooks | 9.2–9.4 |
| A5 大规模并行 | `workflowSizeGuideline=unrestricted`（解锁默认 medium 的规模引导）、`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`、`CLAUDE_CODE_FORK_SUBAGENT=1`、worktree、ultracode workflow 通道（effort 锁定 `xhigh`） | 7.10 / 9.5 |
| A6 / B5 行为一致性 | 全 5.3 单模型、effort 环境变量锁定（xhigh→max）、不设 fallback、升级 SOP、漂移源清单 | 3 / 7.3 / 13 / 14 |
| B1 数据可靠 | 四个 Z.AI MCP + `skipWebFetchPreflight`、数据铁律规程、抽取模型升至 5.3 | 10.2 / 11 |
| B2/B3 口径与时点 | A 股 CLAUDE.md 模板（口径声明块、时点规程） | 10.3 |
| B4 全面性 | `reasoning_effort=max` 锁定、fork/子代理并行核查、检查清单 | 7.3 / 10.4 |
| B5 持续复跑 | bypassPermissions、无人值守重试、headless 例行任务、`preferredNotifChannel=terminal_bell`（完成/待输入铃声）、`minimumVersion=2.1.233`（门槛硬执行） | 7.9 / 7.11 / 7.12 / 10.5 |
| B6 推理可审 | `alwaysThinkingEnabled`、`showThinkingSummaries`、Preserved Thinking、fullscreen 渲染（压缩后全量回滚 + `Ctrl+O` 全文检索） | 7.3 / 7.12 |
| C1 多模态可读 | vision 子代理（`model: glm-5.3-flash`）+ Read 图片/PDF 分页 + ffmpeg 视频抽帧 | 7.13 / 11 |
| C2 主线不妥协 | flash 零别名位、不设 `CLAUDE_CODE_SUBAGENT_MODEL` | 3 / 7.13 / 8 |
| C3 视觉可靠性 | vision 子代理系统提示（转录先行/裁剪保全/不确定性标注） | 11 |

---

# 第二部分：配置

## 5. 工作原理速览

### 5.1 网关模式

Claude Code 通过 `ANTHROPIC_BASE_URL` 将全部模型请求改发至兼容 Anthropic Messages 协议的端点；该变量仅改变"请求发往何处"，不改变"哪个模型回答"。Z.AI Coding Plan 的 Anthropic 协议专属端点为 `https://api.z.ai/api/anthropic`（使用普通 API 端点会脱离套餐计费并产生 1113 余额错误）。

- 来源：[Claude Code – Model configuration](https://code.claude.com/docs/en/model-config)、[Z.AI – Quick Start（Endpoint Guide）](https://docs.z.ai/devpack/quick-start)、[Z.AI – FAQ](https://docs.z.ai/devpack/faq)

### 5.2 别名映射与 effort 映射

模型别名（opus/sonnet/haiku/fable）由 `ANTHROPIC_DEFAULT_*_MODEL` 解析（见第 3 章矩阵）。Claude Code 的 effort 档位经 Z.AI 端点映射为 GLM-5.3 的 `reasoning_effort`：

| Claude Code effort | GLM-5.3 reasoning_effort |
| --- | --- |
| `low` / `medium` / `high` | `high` |
| `xhigh` / `max` / `ultracode` | **`max`**（GLM-5.3 的最深推理档，也是其 API 默认值） |

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
2. 将 [`agents/vision.md`](./agents/vision.md) 部署至 `%USERPROFILE%\.claude\agents\vision.md`（多模态专线，全项目可用；与其他供应商配置共用同一部署位时，切换供应商须同步替换此文件——两个配置库的 vision 子代理指向各自端点的视觉模型，混用必然路由失败）。
3. 关闭全部既有会话窗口后重新启动 `claude`，首次提示 "Do you want to use this API key?" 时选择 Yes。

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

### 7.2 模型矩阵（全 5.3）

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.ANTHROPIC_DEFAULT_OPUS_MODEL` | `glm-5.3[1m]` | 主力位。`[1m]` 使 Claude Code 按 1M 窗口管理会话，发送前自动剥除后缀。 |
| `env.ANTHROPIC_DEFAULT_SONNET_MODEL` | `glm-5.3[1m]` | 覆盖一切解析到 sonnet 的路径。 |
| `env.ANTHROPIC_DEFAULT_FABLE_MODEL` | `glm-5.3[1m]` | 覆盖 `fable`/`best` 别名路径。 |
| `env.ANTHROPIC_DEFAULT_HAIKU_MODEL` | `glm-5.3` | **后台辅助功能同样采用旗舰模型**（第 3 章）。`[1m]` 后缀在 Haiku 位无官方文档保证且后台任务极短，故使用裸模型名——这是文档边界内的最强配置。 |
| `model`（顶层） | `opus` | 会话启动模型显式声明，杜绝默认值漂移。 |
| 子代理模型 | （不设 `CLAUDE_CODE_SUBAGENT_MODEL`） | 常规子代理默认 `inherit` 继承主会话的 glm-5.3[1m]；vision 子代理按 frontmatter 命中 glm-5.3-flash（第 3 章、7.13）。设置该变量会覆盖 vision 路由——绝不设置（第 8 章）。 |
| `env.ANTHROPIC_DEFAULT_*_MODEL_NAME` / `_DESCRIPTION` | `GLM-5.3 (1M)` 等 | `/model` 选择器显示名（官方说明 `_NAME`/`_DESCRIPTION` 在网关模式生效）。 |
| `env.ANTHROPIC_DEFAULT_*_MODEL_SUPPORTED_CAPABILITIES` | `effort,xhigh_effort,max_effort,thinking,adaptive_thinking,interleaved_thinking`（四个位一致） | 向 Claude Code 声明自定义模型 ID 支持的能力，解锁 effort 滑杆、xhigh/max 档、思考渲染、工具间思考。四个位均为 GLM-5.3，能力声明统一设置为最大。官方文档明确该变量在第三方 provider 生效、网关场景以 `CLAUDE_CODE_ALWAYS_ENABLE_EFFORT` 为主保险（7.3），此处为无副作用的冗余保险。 |

- 来源：[Claude Code – Model configuration（Environment variables / `[1m]` / Customize pinned model display and capabilities）](https://code.claude.com/docs/en/model-config)、[Z.AI – How to Switch Models](https://docs.z.ai/devpack/latest-model)

### 7.3 思考深度：锁定 reasoning_effort=max（A6 / B4 / B6）

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.CLAUDE_CODE_EFFORT_LEVEL` | `xhigh` | **锁定档**。环境变量是 effort 的最高优先级来源（高于 `/effort` 与 `effortLevel` 设置），锁定效果与 `max` 完全相同。之所以锁定 `xhigh` 而非 `max`：① 经 Z.AI 映射，`xhigh` 与 `max` 均落到 GLM-5.3 的 `reasoning_effort=max`，**推理深度无差别**；② 官方明确"当 `CLAUDE_CODE_EFFORT_LEVEL` 被设为 xhigh 以外的档位时，请求按该档执行且 **ultracode 的 workflow 编排保持关闭**"——即锁定 `max` 会随之关闭 ultracode 的动态工作流编排（A5 大规模并行审计、B4 多角度交叉核查的主力通道），而 ultracode 本身发送给模型的本就是 `xhigh`。锁定 `xhigh` 即以相同的最深推理保留自动编排通道，为严格占优的选择。 |
| `effortLevel`（顶层） | `xhigh` | 冗余保障层：若上述环境变量被移除，会话仍持久落在 xhigh——经 Z.AI 映射仍是 `reasoning_effort=max`，双重保障。 |
| `env.CLAUDE_CODE_ALWAYS_ENABLE_EFFORT` | `1` | Claude Code 默认仅对其识别的 Claude 模型 ID 发送 effort 参数；`glm-5.3` 是自定义 ID，不设此项 effort 可能根本不随请求发出。官方原文："Use this when routing through an LLM gateway or third-party provider that serves models under custom identifiers." |
| `alwaysThinkingEnabled`（顶层） | `true` | 所有会话默认扩展思考。GLM-5.3 在 Coding Plan 端点本就默认 `thinking.type=enabled`，此项保证客户端不发出关闭思考的请求形态。 |
| `showThinkingSummaries`（顶层） | `true` | 思考内容在界面可见（`Ctrl+O` 展开）——B6"推理可审"的界面开关。A 股结论必须回看推理链；BMC 大改动前亦应审查其方案推演。 |

配额倍率提示（可用性视角，非费用视角）：GLM-5.3 属旗舰（Opus 级）模型，按 5.2 时代规则峰时 3×、非峰 2× 计入套餐配额（5.3 的 FAQ 未再单列倍率，即便存在出入亦不改变处置）。这不改变任何决策——触及 5 小时窗口上限时按第 12 章切换账号即可。

- 来源：[Claude Code – Model configuration（Adjust effort level：max 持久化例外条款、优先级顺序）](https://code.claude.com/docs/en/model-config)、[Claude Code – env-vars（`CLAUDE_CODE_EFFORT_LEVEL`、`CLAUDE_CODE_ALWAYS_ENABLE_EFFORT`）](https://code.claude.com/docs/en/env-vars)、[Claude Code – Settings（`alwaysThinkingEnabled`、`showThinkingSummaries`、`effortLevel`）](https://code.claude.com/docs/en/settings)、[Z.AI – How to Switch Models（effort 映射、max 推荐）](https://docs.z.ai/devpack/latest-model)、[Z.AI – Coding Plan Overview（倍率）](https://docs.z.ai/devpack/overview)

### 7.4 上下文：1M 窗口 + 800K 压缩水位（A1）

#### 7.4.0 定调：为什么不是"1M 用到尽头"

窗口大小与压缩水位是**两个独立旋钮**：`[1m]` 后缀声明容量（模型能装多少），`CLAUDE_CODE_AUTO_COMPACT_WINDOW` 声明水位（装到多满时把对话史压缩成摘要）。旧版配置将水位设为满格 1000000（照抄 Z.AI 启用 1M 的示例值），实测后果是**会话逼近 1M 时手动/自动压缩双双失败、整个会话不可恢复**，只能导出重开。本节将水位调整为 800000，定调依据分两层，二者相互独立、各自充分：

**第一层（机制层）：满格水位使压缩在结构上必然失败。**

1. **压缩本身是一次模型请求**：官方明确自动压缩与 `/compact` 是同一操作——把**全部对话史 + 摘要指令**发给模型生成摘要。请求发出时还要叠加 `max_tokens` 输出预留（本配置 131072）与思考开销（v2.1.198 起压缩请求继承会话的扩展思考配置，本配置恒为 `reasoning_effort=max`）。水位=1M 意味着压缩恰好在"历史已占满窗口"时才启动——此时 `历史(~1M) + 摘要指令 + 131K 输出预留 > 模型真实上限`，压缩请求本身被服务端拒绝。**手动 `/compact` 同理失败**（同一请求形态），且自动压缩连续失败 3 次后官方熔断器停止重试——会话就此死锁。
2. **网关场景没有"错误触发式"最后防线**：官方明确，靠"prompt is too long"报错触发的兜底压缩**要求报错文案是 Claude Code 可识别的**——"Claude Code doesn't run that recovery when a gateway rewrites the error to wording Claude Code doesn't recognize"。Z.AI 网关的报错文案不在识别列表内，撞墙后没有任何自动恢复路径。
3. **Anthropic 对自家 1M 模型同样不用满格**：官方默认下 Sonnet 5 的 1M 会话在 **约 967K** 即自动压缩（v2.1.247 changelog 原文），即 Anthropic 直连、自家分词、32K 输出预留的最优条件下也保留 3%+ 余量。经网关 + 128K 输出预留 + 第三方分词计数的条件下，余量必须显著更大。
4. **800000 的算术**：压缩请求规模 ≈ 800K 历史 + 摘要指令 + 131072 输出预留 ≈ 935K < 1M，留 ~65K 结构余量吸收系统提示、思考与计数偏差；触发前的每一轮常规请求同样满足 `输入 + 131K ≤ 1M`。水位可按任务在 700K–850K 间调节（`/autocompact` 会报告被环境变量接管；改动属行为漂移，仅在任务边界执行）；**850K 以上余量不足以稳定容纳压缩请求自身，禁入**。

**第二层（质量层）：即便压缩不失败，"用尽 1M"也违背"正确性压倒一切"。** 权威证据一致表明模型质量随上下文填充度上升而下降，且远在名义上限之前：

| 来源 | 性质 | 结论 |
| --- | --- | --- |
| [Claude Code – Best practices](https://code.claude.com/docs/en/best-practices) | 官方文档 | "绝大多数最佳实践基于一个约束：上下文窗口填充得很快，**且性能随填充而下降**……窗口接近满时，Claude 可能开始'忘记'先前的指令或犯更多错误。上下文窗口是最需要管理的资源。" |
| [Anthropic – Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | 官方工程博客 | 提出 **context rot**：随 token 数增加，模型从上下文中准确召回信息的能力下降，"该特性在**所有模型**上出现"；上下文必须被视为**边际收益递减的有限资源**（注意力预算）；并明确"**等待更大的窗口**看似显然，但可预见的未来内，任何尺寸的窗口都受上下文污染与信息相关性问题制约——至少在追求最强 agent 性能的场景下"。长程任务的官方三板斧：压缩、结构化笔记（落盘）、子代理架构——与本手册 9.4/7.10 完全同构。 |
| [Chroma – Context Rot 技术报告](https://research.trychroma.com/context-rot)（2025-07） | 独立实验室受控实验 | 18 个 SOTA 模型（含闭源旗舰与开源权重），**保持任务复杂度恒定、仅变输入长度**："所有实验中，模型性能随输入长度增加而一致性下降"，且退化非均匀；报告明确指出真实任务复杂度更高，实际退化只会比该受控下限更显著。 |
| [NoLiMa（ICML 2025）](https://arxiv.org/abs/2502.05167) | 同行评审论文 | 13 个声称 ≥128K 窗口的模型，剔除字面匹配捷径后：**仅 32K 处就有 11 个模型跌破其短上下文基线的 50%**；GPT-4o 从 99.3% 降至 69.7%。 |
| [RULER（COLM 2024）](https://arxiv.org/abs/2404.06654) | 同行评审论文 | 17 个长上下文模型：NIAH 近满分的模型在稍复杂任务上"几乎全部随长度大幅退化"，**声称窗口 ≥32K 的模型只有一半在 32K 处维持合格表现**——"名义窗口 ≠ 有效窗口"。 |
| [智谱 – GLM-5.3 发布说明](https://docs.bigmodel.cn/cn/guide/models/text/glm-5.3) | 厂商官方 | GLM-5.3 的长程能力来自"**结合上下文压缩机制的 SAO**"强化学习策略——厂商自身的长程任务方案就是压缩 + 分段，而非填满窗口。 |

由此定调：**1M 窗口的价值是"单阶段容量"（一次装下跨栈证据链），不是"会话寿命"（把整个多日任务塞进一个窗口）**。会话寿命由第 9.4 节的上下文生命周期规程承担：证据落盘 → 阶段边界主动压缩/清空 → 从磁盘再引导。旧做法（用尽 1M → 报错 → 导出重开）在两层上都是劣势：末端 20% 的推理恰是全会话质量最低的部分，而崩溃式重开丢失的工作状态远多于一次受控压缩。

#### 7.4.1 参数

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.CLAUDE_CODE_AUTO_COMPACT_WINDOW` | `800000` | **压缩水位**（本次调优核心，依据见 7.4.0）。取值区间 100000–1000000、仅接受纯数字；环境变量优先于 `/autocompact` 命令、`--autocompact` 旗标与 `autoCompactWindow` 设置键，对主会话与子代理一并生效。仍远高于 200K 默认边界，Z.AI"启用 1M 需配套设置压缩窗口"的要求继续满足（该官方示例值 1000000 只演示"解除 200K 提前压缩"，未考虑压缩请求自身的可行性）。注意：设置本变量后，状态栏 `used_percentage` 仍按模型全窗口计量，不再指示压缩触发点。 |
| `env.CLAUDE_CODE_MAX_CONTEXT_TOKENS` | `1000000` | 显式声明窗口大小。按官方三分支语义：主会话的 `glm-5.3[1m]`（含 `[1m]` 的自定义 ID）由后缀直接推定 1M，本变量**不单独生效**；它实际作用于裸名位（Haiku 后台任务的 `glm-5.3`，无后缀的自定义 ID 直接生效，v2.1.193+），并为后缀解析异常的场景兜底。 |
| `env.CLAUDE_CODE_MAX_OUTPUT_TOKENS` | `131072` | 单请求输出上限 = GLM-5.3 的 `max_tokens` 硬上限（默认 65536；5.3 发布说明确认最大输出 128K，与 5.2 一致）。整文件重写、长分析报告单轮完成，不因输出配额被截断。**知情权衡**（官方明示"提高该值会减少触发 auto-compaction 前的可用上下文"）：该预留已计入 7.4.0 的水位算术——800K 水位 + 131K 预留 + 结构余量恰好安全装入 1M，两参数是配套设计，调整任一须重算另一。 |
| `env.CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` | `1` | **多仓库工作区关键项**：默认情况下 `--add-dir`/`/add-dir` 挂载的目录**不加载**其 CLAUDE.md/规则文件；置 1 后各仓库的 `CLAUDE.md`、`.claude/rules/*.md`、`CLAUDE.local.md` 全部载入。BMC 场景将 u-boot、kernel、openbmc、webui 各自的工程约定同时载入上下文（A1/A4）。 |
| `env.CLAUDE_CODE_GLOB_TIMEOUT_SECONDS` | `60` | Glob 文件发现超时从默认 20 秒提高到 60 秒（官方在 WSL 上的默认值）。Yocto 全量源码树等超大目录的检索不因超时遗漏文件（A1/A3）。 |

**不设** `CLAUDE_CODE_DISABLE_1M_CONTEXT`（按 200K 处理）与 `DISABLE_AUTO_COMPACT`/`DISABLE_COMPACT`（800K 水位的自动压缩是避免请求直接失败的最后防线；配合第 9/10 章"关键证据落盘"规程，压缩造成的损失可控）。

- 来源：[Claude Code – Model configuration（Context window and auto-compaction：默认阈值"到达上限才压缩"、`/autocompact`/旗标/设置键/环境变量的优先级与取值、网关自定义 ID 的三分支窗口语义、网关改写报错文案时不执行恢复）](https://code.claude.com/docs/en/model-config)、[Claude Code – Explore the context window（自动压缩与 `/compact` 同机制、压缩请求继承扩展思考配置、What survives compaction）](https://code.claude.com/docs/en/context-window)、[Claude Code – env-vars（`CLAUDE_CODE_AUTO_COMPACT_WINDOW` 取值与优先级、`CLAUDE_CODE_MAX_OUTPUT_TOKENS` 挤占压缩前空间、`CLAUDE_CODE_MAX_CONTEXT_TOKENS`）](https://code.claude.com/docs/en/env-vars)、[Claude Code – CHANGELOG（v2.1.247：Sonnet 5 默认 ~967K 压缩；压缩失败 3 次熔断；1M 模型 + 更小压缩窗口为一等公民配置）](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)、[Z.AI – How to Switch Models（Enable 1M Context）](https://docs.z.ai/devpack/latest-model)、[Z.AI – GLM-5.2（1M/128K 规格）](https://docs.z.ai/guides/llm/glm-5.2)、[Z.AI – Core Parameters（max_tokens 表）](https://docs.z.ai/guides/overview/concept-param)、7.4.0 表内所列权威研究

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
| `env.CLAUDE_CODE_RETRY_WATCHDOG` | `1` | 无人值守级重试：429/529 容量类错误无限重试（按限额重置时间或最长 5 分钟退避等待），其余瞬时错误默认重试提高到 300 次（约 3 小时退避）。**v2.1.239 起语义细化**：报"支出上限/额度耗尽"的 429（含网关侧定时重置的限额）改为**立即失败**而非无限等待——对无人值守恰是正确行为：套餐耗尽时快速失败退出，触发第 12 章多账号轮换，而非整夜空转。官方推荐用于 unattended sessions——B5 盘后无人值守的基石。 |
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
| `permissions.allow` | 20 条 | Shift+Tab 切换到 manual/acceptEdits/plan 模式时的免批清单，见下文。 |
| `permissions.deny` | `[]` | deny 在**一切模式（含 bypass）**下生效，与全自动目标冲突，故保持为空。涉及真实资金的实盘接口防线见 10.6（项目级窄 deny 是官方提供的唯一硬闸）。 |

允许列表设计（工具名以 [tools reference](https://code.claude.com/docs/en/tools-reference) 的权威名为准）：

- `Bash`、`PowerShell`：任意命令；`Read`、`Glob`、`Grep`、`LSP`：读取与搜索（放行后**工作目录之外**的读取同样免批——跨盘符数据目录、下载目录等 Windows 常见场景）；`Edit`、`Write`、`NotebookEdit`：全部文件修改；`WebFetch`、`WebSearch`：网页抓取/搜索；`Agent`、`Skill`、`Monitor`：子代理、技能、后台监视；`EnterWorktree`、`Workflow`：worktree 进入与动态工作流编排；`mcp__zai-mcp-server`、`mcp__web-search-prime`、`mcp__web-reader`、`mcp__zread`：四个专属 MCP 的全部工具（`mcp__<server>` 裸规则匹配该服务器所有工具）。
- **allow 清单的第三重身份**：workflow 调度的子代理**强制运行在 `acceptEdits` 模式并继承此 allowlist，不继承主会话的 bypass**（官方原文："The subagents the workflow spawns always run in `acceptEdits` mode and inherit your tool allowlist, regardless of your session's mode"）。因此即便常驻 bypass，这 20 条也并非冗余——它们是 workflow 大规模并行时的免批通行证；headless 模式下不在清单内的调用会被直接拒绝（"no one to prompt ... follow your configured permission rules without interactive confirmation"）。新部署的 MCP 如需 workflow 使用，应先将 `mcp__<server>` 加入本清单。
- **有意不放行** `ExitPlanMode`：计划审批保留人工闸门——BMC 级大改动先出计划、经确认后执行，是 A4 的低成本高收益环节。
- `EnterWorktree`/`Workflow` 已补入清单：v2.1.24x 起官方 JSON Schema 的权限规则枚举已收录这两个工具名（此前版本的"schema 未收录"注记随之作废），非 bypass 模式下 worktree 进入与 workflow 编排同样零弹窗。
- Shift+Tab 循环为 `manual → acceptEdits → plan → bypassPermissions`（bypass 因 defaultMode 声明而进入循环）；auto 模式依赖 Anthropic 侧分类器与特定 Claude 模型，GLM 网关下不可用、不会出现在循环中。

- 来源：[Claude Code – Tools reference（PowerShell tool、权威工具名）](https://code.claude.com/docs/en/tools-reference)、[Claude Code – Permissions（规则语法、deny 全模式生效、断路器）](https://code.claude.com/docs/en/permissions)、[Claude Code – Permission modes（模式循环与 bypass 进入循环条件、auto 可用性要求）](https://code.claude.com/docs/en/permission-modes)、[Claude Code – Settings（Permission settings、schema 滞后声明）](https://code.claude.com/docs/en/settings)

### 7.10 大规模并行与长任务编排（A5）

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `workflowSizeGuideline`（顶层） | `unrestricted` | 动态 workflow 的规模引导（特性需 v2.1.202+，设置键需 v2.1.219+）。**默认 `medium` 会引导 Claude 只写 <15 个代理的 workflow**——直接压制 A5 全仓审计、B4 多角度核查所需的规模；`unrestricted` 即"无引导、按任务定规模"，与 workflow 单 run 1000 代理的硬上限对齐。官方明确 guideline 只是发给 Claude 的建议而非强制上限；自设值还会替换 Large workflow 警告的默认 25 代理阈值，且 ultracode 会话本就不显示该警告。设置文件提供值时优先于 `/config` 行（该行随之隐藏），防止会话内被误改。 |
| `env.CLAUDE_CODE_ENABLE_TODO_TOOLS` | `1` | 任务清单工具（TaskCreate/TaskGet/TaskUpdate/TaskList）显式锁定。v2.1.233 起较新模型默认**不再提供**这些工具（官方以模型判定为准）；BMC 级长任务、批量迁移依赖任务清单做进度跟踪与断点续查，显式置 1 保证任何版本判定变化下工具都在。 |
| `env.CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS` | `3600000` | 后台子代理"失速"判定从默认 10 分钟放宽到 1 小时——子代理内部单条长构建/长回测命令期间可能没有流式进度事件，默认值会将其误判为失败（A2）。超过 1 小时的构建应改用 `run_in_background` 的后台命令而非阻塞式子代理。 |
| `env.CLAUDE_CODE_FORK_SUBAGENT` | `1` | 启用 fork 型子代理：**继承完整对话上下文**开分支，而非空白起步。金融场景用它并行核查对立假设（多/空论证各 fork 一支，证据不丢失）；工程场景用它在不污染主线的情况下试探激进方案。**v2.1.232 起 fork 在交互会话默认启用，但 `claude -p`/SDK 仍默认关闭**——本配置的无人值守轨道（10.5）全部经 `-p` 启动，置 1 是 headless 下 fork 可用的必要开关。 |
| `env.CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS` | `0` | headless（`claude -p`）模式默认仅等待后台子代理与 workflow **10 分钟**，超时后"remaining background tasks are terminated and the process exits"——即无人值守的深度 workflow 会在 10 分钟被终止，这正是 B5 场景最隐蔽的截断源。官方明确 `0` = 无限等待。交互式会话不受此变量影响。（需 v2.1.182+） |
| `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `1` | 启用实验性 agent teams（主管+队友多实例协作）。队友模型无论按别名解析还是继承主会话，均落在 GLM-5.3（全部别名位已对齐）；**v2.1.234 起官方移除 `/config` 的 Default teammate model 选项，队友恒用 leader 的模型**——主线单旗舰的保障进一步坐实，连可选的偏离入口都已关闭。实验性特性，异常时删除此行即可。 |

子代理规模的官方语义（v2.1.224 起）：单会话**总量**上限（原默认 200）已被官方移除，`CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION` 随之成为 no-op（本配置已同步移除该行）；现行约束为**并发**运行数（`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`，默认 20，v2.1.217+）、**嵌套深度**（默认 3）与 workflow 单 run 1000 代理/16 并发。对 BMC 全仓审计这意味着"超出并发的 spawn 排队等待，而非被拒绝"——是比旧总量上限更适合审计类任务的形态。两个现行约束保持默认的理由见第 8 章（与 `CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY` 同源：调高只会把 429 打向网关）。

- 来源：[Claude Code – Workflows（size guideline 表、Large workflow 警告、ultracode 会话不显示警告、单 run 上限、`CLAUDE_CODE_SUBAGENT_MODEL` 覆盖）](https://code.claude.com/docs/en/workflows)、[Claude Code – env-vars（`CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION` 移除注记、`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`、`CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS`、`CLAUDE_CODE_FORK_SUBAGENT`、`CLAUDE_CODE_ENABLE_TODO_TOOLS`、`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`）](https://code.claude.com/docs/en/env-vars)、[Claude Code – Settings（`workflowSizeGuideline`）](https://code.claude.com/docs/en/settings)、[Claude Code – Tools reference（Agent tool / 后台任务）](https://code.claude.com/docs/en/tools-reference)

### 7.11 留痕与其他

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `cleanupPeriodDays` | `365` | 会话转录保留一年（默认 30 天清理）。分析会话 = 审计底稿（B5）；配合 `/resume` 回溯。可按需继续加大。 |
| `attribution.commit`/`attribution.pr` | `""`/`""` | 关闭提交/PR 中的 Claude 署名（新版 `attribution` 键取代已废弃的 `includeCoAuthoredBy`）。 |
| `language` | `chinese-simplified` | 默认中文回复（亦影响自动会话标题语言）。 |
| `$schema` | schemastore 地址 | 编辑器内自动补全与校验。 |
| `minimumVersion`（顶层） | `2.1.233` | 低于该版本不运行：把 17.2 版本门槛表从"备查"升级为**硬执行**——锚定当前最高特性门槛（`CLAUDE_CODE_ENABLE_TODO_TOOLS`，v2.1.233），配合 `autoUpdatesChannel: "latest"` 切换发布通道时防止降级到门槛以下的旧版（旧版会静默回退多个关键变量到默认行为；门槛随 17.2 表演进同步上调）。 |

- 来源：[Claude Code – Settings（`cleanupPeriodDays`、Attribution settings、`language`、`$schema`、`minimumVersion`）](https://code.claude.com/docs/en/settings)

### 7.12 终端渲染（fullscreen）与完成通知

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `tui`（顶层） | `fullscreen` | 全屏 alt-screen 渲染器（research preview；`/tui fullscreen` / `/tui default` 随时切换，会话完整保留）。对本配置三项实质收益：① **内存恒定**——只渲染可见消息，1M 窗口超长会话不随转录增长吃内存；② **压缩后全量回滚**——auto-compact 之后 `Ctrl+Home` 仍可滚回会话开头查看原始证据（官方明确 fullscreen scrollback 跨多次压缩保留全部早期消息），直接缓解 9.4 落盘规程要对冲的"压缩丢证据"压力；③ **大输出可交互**——折叠的工具输出点击展开（`BASH_MAX_OUTPUT_LENGTH=150000` 的大段结果可优雅回看）、菜单/权限对话框可鼠标点选、`Ctrl+O` 进入 transcript 模式后 `/` 全文检索、`{`/`}` 逐 prompt 跳转、`[` 写回终端原生 scrollback、`v` 甩进外部编辑器。 |
| `env.CLAUDE_CODE_ALT_SCREEN_FULL_REPAINT` | `1` | Windows 专属配套：Windows Terminal 等 ConPTY 主机在增量重绘下会残留错位碎片（官方排障条目"Stale or misplaced text on screen"），修法即全帧重绘。官方已对后台会话与 agent view 在 Windows 上自动启用，**交互式全屏会话需显式设置**。若全屏滚动出现整块空白，可再叠加 `CLAUDE_CODE_DISABLE_VIRTUAL_SCROLL=1`。 |
| `preferredNotifChannel`（顶层） | `terminal_bell` | 完成通知闭环。官方默认仅 iTerm2/Ghostty/Kitty 发桌面通知，**Windows Terminal 默认零通知**——无人值守长任务（10.5 双轨）完成后终端静默无声。设为 `terminal_bell` 后，任务完成或等待输入时终端响铃；配合 Windows Terminal 设置 `bellStyle`（声音/任务栏闪烁/窗口注意）形成完整提醒链。B5"持续复跑"的人机协议：听到铃声 = 产物已落盘待验收。 |

长会话操作速记（fullscreen 模式）：`Ctrl+O` 进 transcript 检索，`/focus` 切安静视图（只显示最后 prompt + 工具调用一行摘要 + 最终响应），滚轮速度 `/scroll-speed` 可调（写入 `CLAUDE_CODE_SCROLL_SPEED`），离开数分钟后回终端自动显示一行会话回顾（`awaySummaryEnabled`，默认开）。agent view 中 attach 的后台会话恒以 fullscreen 渲染，不受本键影响。

- 来源：[Claude Code – Fullscreen rendering（收益、ConPTY 全帧重绘、transcript 检索、压缩后回滚）](https://code.claude.com/docs/en/fullscreen)、[Claude Code – Terminal configuration（terminal bell / `preferredNotifChannel`）](https://code.claude.com/docs/en/terminal-config)、[Claude Code – env-vars（`CLAUDE_CODE_ALT_SCREEN_FULL_REPAINT`、`CLAUDE_CODE_SCROLL_SPEED`、`CLAUDE_CODE_DISABLE_VIRTUAL_SCROLL`）](https://code.claude.com/docs/en/env-vars)、[Claude Code – Settings（`tui`、`awaySummaryEnabled`）](https://code.claude.com/docs/en/settings)

### 7.13 多模态子代理：vision 路由架构（C1 / C2）

多模态不是一个参数，而是一条**路由**。本配置的实现（部署物为 [`agents/vision.md`](./agents/vision.md)，用法与作业规程见第 11 章）：

| 环节 | 机制 | 依据 |
| --- | --- | --- |
| 模型指定 | 子代理 frontmatter `model: glm-5.3-flash`。官方允许 frontmatter 直接写完整模型 ID（"a full model ID… Accepts the same values as the `--model` flag"），无需占用任何别名位；`glm-5.3-flash[1m]` 亦为端点合法字符串（官方 Claude Code 示例用于 Haiku 位），vision 子代理任务短，用裸名（窗口由 `CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000` 对裸名自定义 ID 直接生效兜底，v2.1.193+） | [Sub-agents – Choose a model](https://code.claude.com/docs/en/sub-agents)、[Z.AI – Claude Code 接入](https://docs.z.ai/devpack/tool/claude) |
| 路由优先级 | 子代理模型解析顺序：`CLAUDE_CODE_SUBAGENT_MODEL` 环境变量 > 调用时 model 参数 > **frontmatter** > 继承主会话。本配置不设前者，frontmatter 稳定命中 | [Sub-agents – model 解析顺序](https://code.claude.com/docs/en/sub-agents) |
| 多模态进入 | 三类非文本证据全部收敛为 **image 内容块**这一条通道：图片——子代理 Read 直读（"returned as visual content that Claude can see"）；视频——子代理先用 ffmpeg 抽帧为图片再读（fps 按需：通览 1fps、抓闪现报错 2fps/关键帧）；PDF/文档——Read 的 `pages` 参数分页读（每次 ≤20 页）。**注意口径**：glm-5.3-flash 的图片输入官方文档化于 OpenAI 格式（`image_url`，支持 URL 与 Base64 Data URL）；Anthropic 端点对 image 内容块的转换未见官方单独声明——`glm-5.3-flash` 本身是端点合法模型且具备视觉能力，此环节列为部署验证点（第 15 章第 11 条），验证不过时的回退为 Vision MCP（11.3） | [Z.AI – GLM-5.3-Flash（image_url 用法）](https://docs.z.ai/guides/vlm/glm-5.3-flash)、[Tools reference – Read](https://code.claude.com/docs/en/tools-reference) |
| 客户端压缩 | Claude Code 发送前对大图缩放重压缩；服务端还会按自身规则换算 token（官方未公布 GLM 侧换算细则）。官方建议错过像素级细节时先裁剪感兴趣区域再读——vision 子代理系统提示已内置裁剪规程 | [Tools reference – Read（Images）](https://code.claude.com/docs/en/tools-reference) |
| 深度与窗口 | 子代理 effort 默认继承会话（xhigh 经映射即 `reasoning_effort=max`，flash 同样默认 max）；thinking 配置继承（v2.1.198+）；回传上限 `TASK_MAX_OUTPUT_LENGTH=160000` | [Sub-agents（effort/thinking 继承）](https://code.claude.com/docs/en/sub-agents)、7.5 |
| 观测 | `/tasks` 与代理详情对话框显示每个子代理实际运行的模型与 effort（v2.1.243+）——验证 vision 走的是 flash 的直接手段 | [CHANGELOG v2.1.243](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) |

**为什么不是别的方案**（设计决策记录）：

- ~~主会话直接吃图~~：主线是 GLM-5.3，官方明确 "text-only inputs"，收图即 400（C1 归零）。把主线换成 flash 则违反第 3 章主线基准表——极限长时程代码任务必须旗舰。
- ~~Haiku/Sonnet 位挂 flash + 子代理走别名~~：别名位会把视觉模型暴露进 `/model` 选单与后台任务路径，误操作即主线降级（违反"选单无备选"原则）。frontmatter 直写模型 ID 零暴露。
- ~~Vision MCP 承担日常视觉~~：MCP 方案依赖本地 Node ≥ 22 + npx 拉起 stdio 进程，且工具式调用不带子代理的 effort/thinking 继承与独立上下文。子代理方案在深度（max 思考读图）、上下文（1M）、权限继承上全面占优；其 `video_analysis`（≤8MB）、`ui_diff_check`、`analyze_data_visualization` 等工具的职能均已被 flash 专线覆盖（视频 = 抽帧、UI 比对与图表分析 = 直读）——Vision MCP 定位为 flash 通道异常时的**最后兜底**，不承担日常视觉任务，见 11.3。
- ~~`/model` 手动切换读图~~：主线换模型属最高级别行为漂移（第 14 章），且切回后图片仍在上下文中、后续每轮请求都会再次发往不支持图片的旗舰——结构性错误。

**主会话纪律（必须写入各项目 CLAUDE.md，模板见 9.2/10.3）**：图片一律**不粘贴进对话**（粘贴的图片会随请求发给 GLM-5.3 → 400）；图片以文件形式放入工作区，点名 vision 子代理分析（自动委派或 `@vision`）。

- 来源：见表内逐行标注

## 8. 有意不设置的参数及原因

| 参数 | 决定 | 原因 |
| --- | --- | --- |
| `fallbackModel` | **绝不设置** | 过载时自动切换模型 = 静默降级出活，违反 A6/B1。策略：`CLAUDE_CODE_RETRY_WATCHDOG` 持续重试同一模型，无法等待时按第 12 章切换账号。来源：[Model configuration – Fallback model chains](https://code.claude.com/docs/en/model-config) |
| `CLAUDE_CODE_EXTRA_BODY`（如注入 `temperature`/`top_p`） | 不设置 | 直觉上金融场景倾向低温度采样，但工程判断为不注入：① Anthropic 协议下扩展思考与采样参数存在兼容约束，网关对自定义组合的处理无官方保证，注入即引入未定义行为；② GLM-5.2 官方迁移指南明示默认 `temperature=1.0`、`top_p=0.95`、"recommend choosing only one for tuning"——这是其深思考模式的标定工况（迁移指南尚未更新至 5.3，但 5.3 与 5.2 同基座，标定沿用）；③ **数值的确定性由"工具算数"保证**（10.2 铁律：所有计算落到代码执行），不依赖采样温度。来源：[Z.AI – Migrate to GLM-5.2（Migration Checklist 采样默认值）](https://docs.z.ai/guides/overview/migrate-to-glm-new)、[Z.AI – Core Parameters](https://docs.z.ai/guides/overview/concept-param)、[Claude Code – env-vars（`CLAUDE_CODE_EXTRA_BODY`）](https://code.claude.com/docs/en/env-vars) |
| `MAX_THINKING_TOKENS` | 不设置 | 设 0 会关闭思考；非零值属"固定思考预算"模型的机制。GLM-5.3 思考深度由 `reasoning_effort` 控制且已锁定（7.3）。来源：[Claude Code – env-vars](https://code.claude.com/docs/en/env-vars) |
| `DISABLE_PROMPT_CACHING`（及分模型变体） | 绝不设置 | 缓存是无损机制（第 2 章），关闭无任何收益。来源：[Prompt caching](https://code.claude.com/docs/en/prompt-caching) |
| `ENABLE_PROMPT_CACHING_1H` / `FORCE_PROMPT_CACHING_5M` | 不设置 | Anthropic 官方缓存 TTL 计费选项，Z.AI 隐式缓存不适用。来源：[Prompt caching – Cache lifetime](https://code.claude.com/docs/en/prompt-caching)、[Z.AI – Context Caching](https://docs.z.ai/guides/capabilities/cache) |
| `ENABLE_TOOL_SEARCH` | 保持默认 | 非第一方 host 默认预载全部 MCP 工具（tool search 需网关支持 `tool_reference`，Z.AI 未声明支持，强制开启会导致请求失败）。来源：[env-vars（`ENABLE_TOOL_SEARCH`）](https://code.claude.com/docs/en/env-vars) |
| `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` | 默认不设 | 仅当端点对 `anthropic-beta` 头报错时临时置 1。来源：[env-vars](https://code.claude.com/docs/en/env-vars) |
| `DISABLE_INTERLEAVED_THINKING` | 不设置 | GLM 自 4.5 起默认支持工具间思考——"每个工具结果均被推理消化"正是 A3/B4 的要求。来源：[Z.AI – Thinking Mode](https://docs.z.ai/guides/capabilities/thinking-mode) |
| `DISABLE_AUTO_COMPACT` / `DISABLE_COMPACT` | 不设置 | 800K 水位的自动压缩是避免请求直接失败的最后防线；损失由"关键证据落盘"规程（9.4/10.5）对冲。来源：[env-vars](https://code.claude.com/docs/en/env-vars) |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | 不设置 | 按百分比提前触发压缩（1–100，只能降低不能提高，仅对"限前压缩"会话生效）。压缩触发点已由 `CLAUDE_CODE_AUTO_COMPACT_WINDOW=800000` 以绝对 token 数直接表达（7.4），再叠加百分比旋钮会使实际触发点变成两数乘积、难以推算与验证——单旋钮原则。来源：[env-vars（`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`）](https://code.claude.com/docs/en/env-vars) |
| `CLAUDE_CODE_DISABLE_1M_CONTEXT` | 绝不设置 | 会按 200K 窗口处理。来源：[env-vars](https://code.claude.com/docs/en/env-vars) |
| `ANTHROPIC_API_KEY` | 不设置 | Z.AI 使用 `ANTHROPIC_AUTH_TOKEN`；系统中残留的 `ANTHROPIC_API_KEY` 必须删除。来源：[env-vars](https://code.claude.com/docs/en/env-vars) |
| `CLAUDE_CODE_ENABLE_FINE_GRAINED_TOOL_STREAMING=1` | 可选未启用 | 网关下细粒度工具流默认关闭，仅影响"大段写入的实时观感"，不影响结果；启用属观感优化，若遇工具参数解析错误须移除。来源：[env-vars](https://code.claude.com/docs/en/env-vars) |
| `CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY` | 保持默认 10 | 可提高并行度，但并发受 Z.AI 套餐侧动态限制（Max 档更高、非峰更宽），超发只会产生 429-重试循环。需要更高吞吐时应使用多会话/多账号（第 12 章）。来源：[env-vars（`CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY`）](https://code.claude.com/docs/en/env-vars)、[Z.AI – Usage Policy](https://docs.z.ai/devpack/usage-policy) |
| `sandbox.*` | 不设置 | 沙箱仅支持 macOS/Linux/WSL2；Windows 原生 PowerShell 工具不支持沙箱。来源：[Settings – Sandbox settings](https://code.claude.com/docs/en/settings)、[Tools reference – PowerShell preview limitations](https://code.claude.com/docs/en/tools-reference) |
| `fastMode` / `fastModePerSessionOptIn` | 不设置 | Fast mode 是 Anthropic 原生 Opus 的加速计费特性（更高单 token 费用换更快输出），走 Z.AI 网关无对应通道；且本配置定调"速度不纳入决策考量"，双不沾。`/fast` 命令在网关会话中不可用即无影响。来源：[Fast mode](https://code.claude.com/docs/en/fast-mode) |
| `verbose` | 不设置 | 显示层完整工具输出（v2.1.119+）。"证据不截断"由 7.5 的传输层上限保证；显示层 fullscreen 已提供折叠 + 点击展开，开 verbose 只会把超长输出整段刷进视口，反而降低可读性。来源：[Settings – `verbose`](https://code.claude.com/docs/en/settings) |
| `askUserQuestionTimeout`（及 `CLAUDE_AFK_TIMEOUT_MS`） | 不设置 | AskUserQuestion 对话框空闲超时"自动继续"（默认 `never` 等待作答）。自动继续与 10.6"人工闸门"哲学冲突；headless（`-p`）下问题本就走非交互路径，不存在挂等场景。来源：[Settings – `askUserQuestionTimeout`](https://code.claude.com/docs/en/settings)、[env-vars – `CLAUDE_AFK_TIMEOUT_MS`](https://code.claude.com/docs/en/env-vars) |
| `crossSessionInbound` | 保持默认 `hold` | 跨会话入站消息策略（`accept`/`hold`/`refuse` 阶梯，v2.1.224+；官方 schema 尚未收录该键）。默认 hold 使 bypass 会话收到的入站消息被扣住待批准——这是防提示注入的安全设计；单人多会话确需互通（如 BMC 多会话 + A 股会话互发）时再显式设 `accept`，属未来决策点而非当下需求。来源：[Settings – 跨会话消息入站策略](https://code.claude.com/docs/en/settings) |
| `keybindingFlavor` | 不设置 | readline 风格键位（Ctrl+W 删词等，v2.1.238+；schema 尚未收录）。纯个人键位偏好，与场景需求无关。来源：[CHANGELOG v2.1.238](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) |
| `voice` / channels（`channelsEnabled` 等） | 不设置 | 语音听写需 claude.ai 账号；channels 属 claude.ai Team/Enterprise 管控体系——网关 + API Key 认证下均不可用。来源：[Voice dictation](https://code.claude.com/docs/en/voice-dictation)、[Channels](https://code.claude.com/docs/en/channels) |
| `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` / `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` | 保持默认 20 / 3 | v2.1.217+ 起现行的子代理约束（见 7.10 语义说明）。调高并发与 `CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY`（保持 10）同源：并发受 Z.AI 套餐侧动态限制，超发只产生 429-重试循环；workflow runtime 自身并发上限 16，默认 20 已非瓶颈——大规模审计的正确形态是"总量排队"而非"并发堆高"。来源：[env-vars – 两变量条目](https://code.claude.com/docs/en/env-vars) |
| `CLAUDE_CODE_GOAL_CHECKIN_MINUTES` | 不设置 | `/goal` 长任务的自动 check-in 间隔（默认 30 分钟起逐步退避；v2.1.234+）。当前作业手册未采用 `/goal` 工作流；若日后启用且不欲 check-in 消息注入上下文，设 `0` 关闭。来源：[env-vars – `CLAUDE_CODE_GOAL_CHECKIN_MINUTES`](https://code.claude.com/docs/en/env-vars) |
| `ANTHROPIC_DEFAULT_MODEL` | 不设置 | v2.1.236+ 的"新会话默认模型"变量。与既有顶层 `model: "opus"` 等效（`/model` 选择均可覆盖并持久化），无迁移收益。来源：[env-vars – `ANTHROPIC_DEFAULT_MODEL`](https://code.claude.com/docs/en/env-vars) |
| `CLAUDE_CODE_WORKFLOW_PREFIX_STAGGER_MS` | 保持默认 5000 | workflow fan-out 的缓存前缀错峰：同前缀的兄弟代理等待首代理响应开始后一起放行，读共享缓存前缀而非各自冷处理（v2.1.229+）。对 Z.AI 隐式缓存同样适用，保留默认即免费收益。来源：[Workflows – Prompt caching in a fan-out](https://code.claude.com/docs/en/workflows)、[env-vars](https://code.claude.com/docs/en/env-vars) |
| `CLAUDE_CODE_SUBAGENT_MODEL` | **绝不设置** | 子代理模型解析的最高优先级来源，设置后**覆盖 vision 子代理的 frontmatter**——多模态链路被强制拉回纯文本的旗舰，读图必然 400（C1 归零）。追求"子代理全旗舰"也无需它：不设时默认 `inherit`，常规子代理天然继承主会话的 GLM-5.3 (1M)，与设置 `opus` 效果完全一致；唯一差别正是 vision 子代理的 frontmatter 路由得以生效。来源：[Sub-agents – model 解析顺序](https://code.claude.com/docs/en/sub-agents) |
| `feedbackDrafts` | 保持默认 | v2.1.247 的 SendFeedback 工具草拟反馈经 `/feedback` 发送——该链路属 Anthropic 侧非必要流量，本环境已由 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` 整体关闭，无需单独处理。来源：[CHANGELOG v2.1.247](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) |
| `experimental.cacheTtl`（agent frontmatter） | 不设置 | v2.1.248 新增的每代理 prompt 缓存 TTL（`"5m"`/`"1h"`）。属 Anthropic 官方缓存 TTL 计费机制；Z.AI 为隐式自动缓存（`ENABLE_PROMPT_CACHING_1H` 同判，见上表），客户端 TTL 声明无对应物。vision 子代理 frontmatter 亦不添加。来源：[CHANGELOG v2.1.248](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) |
| `desktopSessionCleanupPeriodDays` | 不设置 | v2.1.248 新增，为 Claude Desktop 写入的会话设置清理豁免上限——claude.ai/Desktop 会话体系专属，纯 API Token 网关模式下不存在该类会话。来源：[CHANGELOG v2.1.248](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) |
| `CLAUDE_CODE_RESTRICTED=1`（`--restricted` 启动旗标） | **绝不使用** | v2.1.248 新增的受限模式：移除命令/代码执行类内置工具与 WebFetch、文件工具禁出工作目录、**拒绝 bypassPermissions、忽略用户级/项目级/本地 settings 文件**——与"无人值守全自动 + 用户级配置"的整套架构正相反。属给受限环境管理员提供的锁定开关，非本场景工具。来源：[CHANGELOG v2.1.248](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) |

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

# 多模态证据规程
- 报错/崩溃截图、原理图、时序图、面板照片、录屏视频、PDF 规范/研报：
  一律以文件落盘（建议 docs/evidence/），点名 vision 子代理处理
  （"用 vision 分析 <路径>：<要回答的问题>"；视频自动抽帧、PDF 自动分页）；
  禁止把图片粘贴进对话——主线模型只接受文本，粘贴即请求报错。
- vision 回传的逐字转录是主线唯一可见的证据载体；关键转录注明
  「文件路径 + vision 转录 + 获取时间」，并按长任务规程落盘存档。
- 视觉估读只用于形态判断；进入计算与结论的数值必须回到代码/数据接口取证。

# 长任务规程
- 阶段性结论（架构判断、影响面清单、风险点）写入 docs/worklog/<日期>-<主题>.md 后再继续，
  确保上下文压缩后证据仍在磁盘上。
- 小时级构建用后台方式运行，期间继续推进可并行的工作。
- 上下文压缩（compact）时必须完整保留：硬性约束全文、当前阶段目标与未完成事项清单、
  已修改文件清单及各自的验证命令、尚未验证通过的失败项与报错原文。

# 检索优先级
上游/开源参考：优先用 zread 工具读 GitHub 仓库结构与源码；网页文档用 web-reader 取全文。
```

### 9.3 任务下达范式

GLM 官方推荐的用法范式本身即为该场景设计（项目级接管、长程重构、生产级规范压力测试）：先"技术审计"（架构图、模块职责、API 契约、数据流、调用链、技术债、约束清单），再下达带边界的改造任务，并以 `/goal` 设定收尾条件使模型持续工作直到验证通过。

每个任务的下达遵循 Z.AI 官方最佳实践的四要素结构——**Goal（要做成什么）/ Context（涉及哪些文件、报错、文档）/ Constraints（工程约束）/ Done when（怎样算完成）**。长期性规则进 CLAUDE.md，临时性指令进提示词，二者不混放。

- 来源：[Z.AI – GLM-5.2（Usage：Project-Level Codebase Takeover / Long-Horizon Refactoring / Production-Grade Standards Stress Test）](https://docs.z.ai/guides/llm/glm-5.2)、[Z.AI – Best Practice（Structure Task Inputs 四要素、"temporary instructions in the prompt, long-lived rules in configuration files"）](https://docs.z.ai/devpack/resources/best-practice)

### 9.4 证据落盘与上下文生命周期规程（两场景通用）

多日任务终会触顶。总原则（与 7.4.0 定调对应）：**证据的持久层在文件系统，不在对话窗口**——压缩摘要会替换对话史，但磁盘文件永久保留，模型可随时重读。在此之上，上下文按生命周期主动管理，而非被动等 800K 水位：

1. **阶段结论必须先落盘**（worklog、影响面清单、决策记录、报告）：这是一切压缩/清空操作无损的前提。CLAUDE.md 模板中的"压缩保留项"指令（9.2/10.3）是官方支持的定制通道（"Customize compaction behavior in CLAUDE.md"），作为落盘的第二重保险。
2. **阶段边界查看 `/context`**：占用 ≥60% 时收尾当前阶段——结论落盘，然后主动 `/compact <聚焦指令>`（如 `/compact 保留驱动接口改动清单与未通过的测试`）。带指令的手动压缩保留"你指定的重点"而非"自动流程猜测的重点"，且在 60–70% 处执行的压缩请求远离一切失败条件。
3. **任务切换一律 `/clear`**：官方明确"无关上下文会降低性能"、"kitchen sink 会话"是第一反模式。切换后用 worklog 文件再引导（"先读 docs/worklog/xxx.md 然后继续 YY"）——干净窗口 + 磁盘证据优于被无关历史稀释的长会话。同一问题纠正超过两次同样适用：`/clear` 后带着教训重写提示词，官方明示这几乎总是优于继续拉扯。
4. **大规模检索交给子代理**：官方定调"上下文是根本约束，子代理是最有力的工具"——全仓探索、长日志分析放入子代理的独立窗口，主会话只收结论（7.10 的 fork/workflow 即此模式的重型形态）。快问快答用 `/btw`（答案不进入对话史）。
5. **部分压缩**：需要保留近期推理全文、只压缩早期探索时，用 `Esc+Esc`/`/rewind` 选中检查点 → **Summarize up to here**（压早留新）或 **Summarize from here**（压新留早）。
6. **兜底路径**（水位调整后理论上不再触达）：若历史会话已在压缩死区卡死——先试 `/rewind` 部分摘要（请求规模小于全量压缩，可能仍可行）；仍失败则导出 + 新会话 + worklog 再引导。此为最后手段而非常规操作。

- 来源：[Claude Code – Best practices（Manage context aggressively：/clear、/compact 指令、/rewind 部分摘要、/btw、CLAUDE.md 定制压缩、两次纠正后重开、子代理与反模式清单）](https://code.claude.com/docs/en/best-practices)、[Claude Code – Explore the context window（When your context fills up、/context）](https://code.claude.com/docs/en/context-window)、[Anthropic – Effective context engineering（compaction / structured note-taking / sub-agent architectures）](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

### 9.5 并行编排

- **计划先行**：大改动先 Shift+Tab 进入 plan 模式出计划，`ExitPlanMode` 未放行，计划必经人工审批（A4 人工闸门）。
- **worktree 隔离**：并行修改多分支时让 Claude 使用 worktree（默认 `.claude/worktrees/` 路径下创建/进入不弹窗），互不污染。
- **批量审计/迁移使用动态工作流**：workflow 是"计划写入脚本"的重型编排——阶段化、可并行、可对抗互验、可保存复跑，官方定位即"codebase audits、large migrations、cross-checked research"，单次可并行调度几十上百个子代理（本配置上限已提高至 1000）。触发方式三种：提示词包含 `ultracode` 关键词（单次）、直接指示"用 workflow 并行审计全部 phosphor-* 服务的 XX 用法"、或 `/effort ultracode` 使本会话对每个有分量的任务自动编排（锁定档为 `xhigh`，该通道处于可用状态）。fork 型子代理用于"带完整上下文的方案对比"。
- **workflow 的两条边界**：① `ultracode` 关键词与"用 workflow"的自然语言请求**仅在人工输入**（交互输入框、IDE 面板、Remote Control、标记 human 的 SDK 输入）时触发；经 `-p` 传入的提示词、计划任务提示词、webhook 一律**不触发**——无人值守需要 workflow 时，使用启动参数 `claude --effort ultracode -p "..."`（见 10.5）。② workflow 子代理**强制 `acceptEdits` + 继承 allowlist，不继承 bypass**——本配置 20 条 allow 已覆盖其全部所需（7.9）。
- **多实例协作**：agent teams 已启用，适合"一人主控 + 多队友分模块"的大迁移。
- **深度代码审查用 `/code-review`**：`/review` 已成为 `/code-review <level> <pr#>` 的别名（v2.1.223+），`high`/`xhigh`/`max` 档在后台 agent 运行、不阻塞主线（v2.1.232+）；不带级别时复用上次级别。`/code-review ultra` 为云端深度审查，需 claude.ai 通道，网关下不可用——本地档位不受影响。
- **长任务托管的第三形态——后台会话（agent view）**：`claude --bg "..."`、会话内 `/bg`、或总控台 `claude agents` 直接派发。会话由 per-user supervisor 进程托管，关闭终端、关闭 shell 甚至睡眠唤醒后仍在运行；`claude attach <id>` 随时进入查看（attach 恒为 fullscreen 渲染），`Space` 免 attach 预览。后台会话默认 worktree 隔离（`worktree.bgIsolation`）。可脚本化管理：`claude agents --json`、`claude logs/stop/respawn <id>`。与 `-p` headless 的分工：`-p` 是"射后不管 + 产物落盘"，`--bg` 是"长任务托管 + 中途可介入"——重大改造期间持续跟进的正确形态。Windows 兼容官方已覆盖（supervisor 无响应时 `claude daemon stop` 会打印 PID，用 `taskkill /PID <pid>` 结束）。
- **研究型工作流的检索指定**：内置 `/deep-research` 工作流依赖内置 WebSearch 工具（网关下不可用）。让 Claude 编写研究工作流时，应明确指定"检索用 `web-search-prime`、读页用 `web-reader`"。

- 来源：[Claude Code – Workflows（定位、规模、adversarial review、ultracode 触发、`/deep-research` 依赖 WebSearch）](https://code.claude.com/docs/en/workflows)、[Claude Code – Agent view（`--bg`/`claude agents`/attach/worktree 隔离/Windows 说明）](https://code.claude.com/docs/en/agent-view)、[Claude Code – Tools reference（EnterWorktree/Agent/Workflow 行为）](https://code.claude.com/docs/en/tools-reference)、[Claude Code – env-vars（子代理与团队相关变量）](https://code.claude.com/docs/en/env-vars)、[CHANGELOG（`/code-review` 别名与后台审查）](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)

## 10. 场景 ②：A 股深度行情分析

### 10.1 总原则

LLM 在金融数据上的唯一可靠形态是**编排器**而非数据库：它负责取数、编写代码计算、交叉验证、组织论证；数字本身必须全部来自工具调用。以下规程将这一点制度化。

### 10.2 数据铁律（写入 CLAUDE.md，同时也是验收结论的标准）

1. **零记忆数字**：任何行情/财务/宏观数字，禁止直接引用模型记忆；必须来自当轮工具调用（本地数据接口或 MCP 检索），并标注「来源（接口名或 URL）+ 获取时间」。
2. **计算全部落代码**：均线、波动率、估值分位、组合归因等一律由 Python 代码算出（Bash/PowerShell 工具执行），模型不做心算——采样随机性不影响 `pandas` 的输出，这才是"数值绝对可靠"的机制保证（也是第 8 章不调整 temperature 的底气）。
3. **双源交叉**：进入结论的关键数字（收盘价、涨跌幅、成交额、财务科目）至少两个独立来源核对；不一致时必须报告差异与取舍理由。
4. **来源分级**：交易所与法定披露渠道（上交所/深交所官网、巨潮资讯网、中国结算、央行/统计局/证监会）> 结构化数据接口（如 akshare/tushare/baostock 等本地库）> 财经媒体/聚合站。级别低的来源只能佐证，不能独立支撑结论。
5. **有损工具不入账**：WebFetch 是"小模型抽取"的有损设计（官方明示 lossy by design；本配置已将抽取模型升至 GLM-5.3，但仍是单遍抽取）——关键数字取证使用 **web-reader MCP 全文** 或 Bash 中 `curl`/`python requests` 获取原始页面，WebFetch 仅用于泛读。
6. **搜索走 web-search-prime**：内置 WebSearch 在网关下不可用；时效信息（政策、公告、突发）一律 `web-search-prime` 检索 + `web-reader` 取全文。
7. **图表与文档证据走 vision 子代理**：K 线图、仪表盘截图、研报 PDF/扫描件由 vision 子代理（glm-5.3-flash）读取并逐字转录，录屏/视频经抽帧取证（11.0 作业规程），避免人工转录误差；Vision MCP 仅作 flash 通道异常时的最后兜底（11.3）。

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

# 上下文压缩保留项（compact 时不可丢弃）
- 口径声明块全文；数据来源清单表（数值|来源|获取时间|校验源）；
  未完成核查项清单；已形成结论的可证伪条件。
```

### 10.4 深度与全面性的执行手段

- `reasoning_effort=max` 已锁定（7.3 的 xhigh 经 Z.AI 映射即 max），无需在提示词中要求"深度思考"。
- 全面性依靠**结构**而非"多想想"：要求模型按 10.3 检查清单逐项核对，并使用 fork/子代理并行核查——例如"fork 两支分别构建多头与空头最强论证，主线汇总裁决"（fork 继承完整上下文，证据不丢失，见 7.10）。
- **重大专题使用对抗互验工作流**：workflow 的官方设计即包含 "independent agents adversarially review each other's findings before they're reported"（独立代理互相对抗审查后才汇报）——对"某行业景气拐点是否成立"这类命题，指示"用 workflow：多角度分头取证 → 交叉互验 → 汇总裁决，检索一律用 web-search-prime、读页用 web-reader"，较单线程结论具有显著更高的可信度。
- 每份报告强制设"反方论证"章节：主动用 web-search-prime 检索看空/风险观点并逐条回应，纠正单边倾向。
- **上下文生命周期同样执行 9.4 规程**：盘后长会话在专题之间 `/clear` + 报告文件再引导；单专题内多轮取数后 `/context` ≥60% 即落盘报告再 `/compact`。行情数字属"当轮工具调用"证据（10.2 铁律），被摘要替换后**不得**凭摘要复述数字——重新取数或从落盘报告读取。
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
3. workflow 子代理在 headless 下无人可询问：不在 allowlist 的调用被直接拒绝（而非弹窗）——本配置 20 条 allow 已覆盖（7.9）。

其余要点不变：`-p` 沿用同一份用户级 settings（bypass、重试看门狗、MCP 全部生效）；产物落盘 = 审计底稿；`cleanupPeriodDays=365` 保留转录一年；会话内轻量轮询另有 `/loop`。无人值守会话无人执行手动压缩，800K 水位的自动压缩（7.4）即其上下文安全网——这正是水位必须落在"压缩必然可行"区间的原因之一。

- 来源：[Claude Code – Workflows（关键词仅限人工输入、`--effort ultracode`、acceptEdits 语义、headless 无交互确认）](https://code.claude.com/docs/en/workflows)、[Claude Code – env-vars（`CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS`、`CLAUDE_CODE_RETRY_WATCHDOG`）](https://code.claude.com/docs/en/env-vars)、[Claude Code – Agent view（`claude --bg` 派发旗标、supervisor 托管）](https://code.claude.com/docs/en/agent-view)、[Claude Code – Overview（headless/`-p`、`/loop`）](https://code.claude.com/docs/en/overview)

需要中途跟进的重大专题可改用**后台会话形态**：`claude --bg --effort ultracode "..."`（派发支持 `--effort` 等旗标，语义同 `claude agents` 派发；注意 `--bg` 传入的提示词同 `-p` 一样**不触发** ultracode 关键词，必须用旗标）——supervisor 托管下关闭终端不中断，`claude agents` 总控台随时 attach 查看进度，完成/待输入时终端铃声提醒（7.12）。产物仍按数据铁律落盘，无人值守语义与 `-p` 一致；`claude agents --json` 可纳入任务计划程序做编排。

### 10.6 实盘边界（唯一建议保留的硬闸）

分析与执行必须物理分离：实盘下单脚本置于独立仓库，在**该仓库**的 `.claude/settings.local.json` 中添加窄 deny（如 `"Bash(python live_trade.py*)"`、`"Edit(//C/trading/keys/**)"`）。deny 规则在包括 bypass 在内的一切模式下生效，是官方提供的唯一硬闸；分析工作区保持零 deny 全自动。

- 来源：[Claude Code – Permissions（deny 全模式生效、路径规则语法）](https://code.claude.com/docs/en/permissions)

---

# 第四部分：运维

## 11. 多模态证据作业手册与专属 MCP 部署

### 11.0 多模态证据作业手册（vision 子代理）

架构与机制见 7.13；本章为使用规程。vision 子代理是**两场景共用**的多模态证据通道：BMC 侧的报错截图、原理图、时序图、面板照片、复现录屏、PDF 规范，A 股侧的 K 线图、研报 PDF/截图、数据平台图表——图片直读、视频抽帧、PDF 分页，全部由 flash 的多模态承载处理。

**部署与触发**

- 部署：[`agents/vision.md`](./agents/vision.md) → `%USERPROFILE%\.claude\agents\vision.md`（用户级，全项目可用；亦可放入 `<项目>\.claude\agents\` 做项目级覆写）。
- 触发：主线依据子代理 `description` **自动委派**（其中已声明"任何涉及图片、视频或文档文件的任务必须委派本代理"），亦可 `@vision` 显式点名。可靠的下达格式：**文件路径 + 要回答的问题**——"用 vision 分析 `logs/crash-0827.png`：提取完整报错栈与可见的环境信息"、"用 vision 看 `docs/spec-redfish.pdf` 第 12–14 页：转录 Chassis 集合的属性表"、"用 vision 分析 `docs/evidence/repro-0827.mp4`：找出报错弹窗出现的时刻与全文"。
- 观测：`/tasks` 或代理详情应显示该子代理运行于 `glm-5.3-flash`（部署后按第 15 章第 11 条验证一次）。

**多模态规程（防 400 与防细节丢失）**

1. **视觉内容永远是文件，不是粘贴物**：粘贴进主会话输入框的图片会随请求发给 GLM-5.3（纯文本模型）→ 请求报错。规程：截图/录屏/PDF 落盘到工作区（建议 `docs/evidence/`、`charts/`），对话中只出现路径，点名 vision 处理。
2. **图片直读**：JPEG/PNG/GIF/WebP，Read 工具路径。大图先裁剪——两级压缩会吃掉细节（客户端对超大图片缩放重编码后才发送；服务端再按自身规则换算，Z.AI 未公布 GLM 侧换算细则）。vision 子代理的系统提示已内置裁剪规程（高分屏截图的局部报错、密集小字、需精确读数的图表，先用 Python Pillow/ImageMagick 裁出感兴趣区域再读，必要时分块）；下达任务时主动指出关注区域（"右下角的报错弹窗"）能显著提高转录质量。
3. **视频走 flash 抽帧**（不依赖 MCP 的 8MB `video_analysis`）：子代理用 ffmpeg 抽帧后逐帧读——通览用 `fps=1`、抓闪现报错/弹窗用 `fps=2` 或全关键帧；长视频先低密度通览、再对可疑片段高密度重抽；产出要求带时间点（"t=00:14 处出现红色弹窗，文字为……"）。ffmpeg 缺失时 `winget install Gyan.FFmpeg`。
4. **PDF/文档分页读**：Read 的 `pages` 参数（每次 ≤20 页）；页数多时先读目录页定位再精读。研报扫描件、DSP0266 等规范 PDF 均走此路径。
5. **转录即证据**：vision 回传的文本是主线唯一可见的证据载体（主线看不到原始文件）。关键转录按 9.4 落盘；报告中引用时注明「文件路径 + vision 转录 + 获取时间」。
6. **视觉读数不进计算**：图表估读只用于形态判断与线索定位；进入计算与结论的数值必须回到数据接口/原文取证（10.2 第 7 条）。

**典型任务模板**

```text
# debug 截图（BMC/CI 报错）
用 vision 分析 docs/evidence/ci-fail-0827.png：逐字提取报错消息、错误码、栈帧与文件行号；
记录截图中可见的环境线索（终端标题/路径/版本号/时间戳）；报错被截断处明确标注。

# UI 走查（前端还原度）
用 vision 对比 docs/evidence/design.png 与 docs/evidence/actual.png：
按区块列出布局/配色/字号/间距差异，标注各差异在截图中的位置；不确定处标注"不可辨认"。

# 架构图/时序图理解
用 vision 读 docs/evidence/ipmb-timing.png：转录全部节点/信号名与连线关系，
输出时序步骤清单；图中文字不可辨认处逐项列出，不得脑补。

# K 线/图表读数（A 股）
用 vision 读 charts/601398-daily.png：先锁定口径（坐标轴含义、时间范围、复权标注、成交量单位），
再描述形态（趋势、跳空、放量位置），读数一律带估读精度区间；提醒主线：精确数值回数据接口取。

# 复现录屏/视频取证（BMC、UI 回归）
用 vision 分析 docs/evidence/repro-0827.mp4：抽帧找出报错弹窗/崩溃画面出现的全部时刻，
逐字转录弹窗文字与可见的终端输出；描述触发前的操作序列。

# PDF 规范/研报阅读
用 vision 读 docs/spec-redfish.pdf 第 12–14 页：逐字转录 Chassis 集合属性表的
属性名/类型/读写权限/描述列；表格截断或跨页处明确标注。
```

**已知边界**

- GLM-5.3-Flash 为正式发布的原生多模态模型（非 `-exp` 实验后缀），但**多模态官方文档化于 OpenAI 格式（`image_url`）**；Anthropic 端点对 image 内容块的转换为未单独声明的环节——列为部署验证点（第 15 章第 11 条），验证不过时按 16 章回退 Vision MCP（11.3）。
- flash 的视频/文件模态在 API 直调场景有原生输入格式，但 Claude Code 工况下一切非文本证据统一收敛为 image 块（视频抽帧、PDF 分页）——只需验证并守住这一条通道，即以最简路径用满 flash 的多模态承载。
- vision 子代理的任何非视觉任务不得委派（其文本能力为 Flash 级，低于主线旗舰）——子代理 description 与本手册规程双重约束。

- 来源：[Z.AI – GLM-5.3-Flash（多模态能力与 image_url 用法）](https://docs.z.ai/guides/vlm/glm-5.3-flash)、[Claude Code – Tools reference（Read 图片压缩行为）](https://code.claude.com/docs/en/tools-reference)、[Claude Code – Sub-agents（自动委派依据 description）](https://code.claude.com/docs/en/sub-agents)

### 11.1 专属 MCP 概览与配额

四个专属 MCP 是 Coding Plan 的套餐能力。MAX 档配额：Web Search + Web Reader + Zread **共享每月 4000 次**；Vision 走套餐 5 小时 prompt 资源池。配额用尽仅暂停 MCP，不扣除余额；多账号下按第 12 章切换账号即恢复。

- 来源：[Z.AI – Coding Plan Overview（Exclusive MCP / MCP Usage Limits）](https://docs.z.ai/devpack/overview)、[Z.AI – FAQ](https://docs.z.ai/devpack/faq)

### 11.2 部署须知（Windows）

- `-s user` 表示用户作用域：写入 `%USERPROFILE%\.claude.json`（MCP 的用户/本地作用域存储于此，**而非** settings.json），全项目生效；项目作用域写入 `.mcp.json`。
- Vision 是本地 stdio 服务器（npx 拉起 Node 进程，要求 **Node.js ≥ 22**）；其余三个为远程 HTTP 服务器，零本地依赖。
- 亦可使用官方交互助手一次性配置：`npx @z_ai/coding-helper`（Node ≥ 18）。
- 来源：[Claude Code – MCP（installation scopes）](https://code.claude.com/docs/en/mcp)、[Z.AI – Coding Tool Helper](https://docs.z.ai/devpack/extension/coding-tool-helper)

### 11.3 Vision MCP（视觉理解，本地 stdio）——最后兜底

**定位**：一切多模态证据的**主通道**是 vision 子代理（glm-5.3-flash，7.13/11.0）——图片直读、视频抽帧、PDF 分页全部走 flash 的多模态承载，带 effort/thinking 继承（max 思考读图）、1M 上下文与权限继承，不依赖本地 Node 进程。本 MCP 的全部工具职能（`video_analysis` ≤8MB、`ui_diff_check`、`analyze_data_visualization`、`diagnose_error_screenshot` 等）均已由 flash 专线覆盖，**仅在 flash 通道异常时启用**（Anthropic 端点 image 块验证不过、或子代理链路故障，见 16 章）——它是最后兜底，不承担日常视觉任务。

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

### 11.4 Web Search MCP（实时检索，远程 HTTP）

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

### 11.5 Web Reader MCP（网页全文，远程 HTTP）

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

### 11.6 Zread MCP（GitHub 仓库理解，远程 HTTP）

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

### 11.7 部署后验证

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
| `/model` 切换模型 | 不同模型 = 不同回答者 | 本配置为全 5.3 单模型，选单中已无备选；不得手动指定其他模型 |
| `/effort` 切换档位 | 推理深度改变（Claude Code 会弹出确认框） | 已用环境变量锁定 xhigh（经映射即 max），`/effort` 实际失效 |
| 升级 Claude Code | 系统提示词/工具定义变化 | 第 13 章 SOP：仅在任务间隙升级 |
| MCP 服务器中途连接/断开 | 工具定义集合变化 | 四个 MCP 一次配置完成不再变动；服务器抖动由 `MCP_TIMEOUT` 与重连机制吸收 |
| 以裸工具名 deny 工具 | 工具集合变化 | deny 保持为空（第 7.9） |
| `/compact` 压缩 | 对话史被摘要替换 | 安排在任务之间或阶段边界（9.4 规程：先落盘、再带聚焦指令压缩），不在论证中途执行 |
| `/autocompact`/`--autocompact` 中途改水位 | 压缩触发点改变 | 水位由环境变量锁定 800K（7.4），`/autocompact` 仅报告接管状态；调整水位属任务边界操作 |
| 中途修改 CLAUDE.md | 本会话不生效（下次 `/clear`/重启才生效），易产生"以为已修改"的错觉 | 修改规则后重启会话再开工 |
| 中途修改 `agents/vision.md` | 同上（子代理定义会话启动时装载） | 同上 |

无漂移风险、可随时执行：编辑仓库文件、Shift+Tab 切换权限模式、调用技能/命令、`/recap`、`/rewind`、派生子代理。

观测手段（按需使用、无常驻组件）：`/status` 查看模型与设置来源、`/context` 查看窗口占用与压缩水位、`/effort` 确认档位被环境变量接管；缓存读写可在 Z.AI 侧响应的 `usage.prompt_tokens_details.cached_tokens` 观察。本配置无常驻状态栏组件——漂移的结构性来源已在配置层消除（见上表对策），如需临时观测，可使用官方 `/statusline` 命令按需生成。

- 来源：[Claude Code – Prompt caching（cache 字段含义）](https://code.claude.com/docs/en/prompt-caching)、[Claude Code – Statusline（`/statusline` 命令）](https://code.claude.com/docs/en/statusline)、[Z.AI – Context Caching](https://docs.z.ai/guides/capabilities/cache)

## 15. 部署后验证清单

| # | 动作 | 期望结果 |
| --- | --- | --- |
| 1 | `claude --version` | ≥ v2.1.233（全部版本门槛见 17.2；低于 `minimumVersion` 会拒绝启动） |
| 2 | 启动 `claude` | 无认证报错；`⏵⏵ bypass permissions on` 徽标 |
| 3 | `/status` | Setting sources 含 User settings；Model 为 `glm-5.3[1m]`（显示名 GLM-5.3 (1M)） |
| 4 | `/model` | 各别名位均显示 GLM-5.3；**无**任何 4.7/turbo 备选项 |
| 5 | `/effort` | 提示档位被环境变量接管（xhigh） |
| 6 | `/context` | 窗口按 1M 计（注意：状态栏 `used_percentage` 按全窗口计量，不指示 800K 触发点） |
| 6a | `/autocompact`（不带参数） | 报告水位 800000 且由环境变量 `CLAUDE_CODE_AUTO_COMPACT_WINDOW` 接管，命令不可修改 |
| 7 | 复杂提问 | 思考过程可见（`Ctrl+O`），流式稳定 |
| 8 | `claude mcp list` | 四个 MCP 全部 connected |
| 9 | "搜索今天沪深两市成交额并给来源" | 走 `web-search-prime`+`web-reader`，无权限弹窗，数字带来源与时间 |
| 10 | 用 `web-reader` 拉取长页面（如一份完整年报页） | 全文返回，不被 60 秒/5 分钟截断 |
| 11 | 项目放置一张报错截图，"用 vision 分析 error.png，提取完整报错栈" | 主线委派 vision 子代理；`/tasks`/代理详情显示其模型为 `glm-5.3-flash`；回传逐字转录。**若 vision 读图报错**（Anthropic 端点图片块环节，见 7.13/11.0）：按 16 章回退 Vision MCP 并将现象记录进第 8 章取舍 |
| 11a | 同一张图直接粘贴进主会话输入框（**边界验证，做一次即可**） | 请求报错（GLM-5.3 纯文本模型不接受图片）——印证 11.0 规程"图片永远是文件" |
| 12 | 提示词包含 `ultracode` 下达审计任务 | 触发 workflow 编排，`/workflows` 可见并行子代理 |
| 13 | Shift+Tab | manual → acceptEdits → plan → bypass 循环 |
| 14 | 日常断开 Anthropic 访问 | 无升级/遥测报错刷屏；WebFetch 可用（预检已跳过） |
| 15 | `/tui`（不带参数） | Current renderer: fullscreen（输入框固定底部不随输出移动即已生效） |
| 16 | 长任务运行期间切换到其他窗口 | 完成或等待输入时终端铃声（Windows Terminal 需在设置中为 bellStyle 启用声音/任务栏闪烁至少一项） |
| 17 | 下达含多步清单的任务 | 任务清单工具可用（TaskCreate/TaskUpdate 正常被调用，未被新版默认移除） |
| 18 | 提示词包含 `ultracode` 下达大型审计 | workflow 编排的代理数量按任务规模展开（不被 medium 引导压在 15 以内，见 7.10） |

## 16. 故障排查速查表

| 症状 | 原因 | 处置 |
| --- | --- | --- |
| `1113 Insufficient Balance` / 扣除账户余额 | Base URL 错误（走了普通 API 端点）或模型名不在允许列表 | 核对 `https://api.z.ai/api/anthropic` 与 glm-5.3；[Z.AI FAQ](https://docs.z.ai/devpack/faq) |
| `glm-5.3[1m]` 模型不存在 | CLI 版本过旧 | VPN 下升级；[Z.AI – 切换模型](https://docs.z.ai/devpack/latest-model) |
| 修改 settings 不生效 | JSON 语法错误/文件位置错误/旧窗口 | 全部关闭重开；`/status` 查看 sources；`claude doctor`；[Z.AI – Claude Code FAQ](https://docs.z.ai/devpack/tool/claude) |
| 响应中途中断 | 链路抖动 | 已含重试看门狗；频发时检查本地代理是否拦截 `api.z.ai` |
| `anthropic-beta` 头报错 | 端点不识别某 beta | 临时添加 `"CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "1"`；[env-vars](https://code.claude.com/docs/en/env-vars) |
| 主线收到图片请求报错（400 类） | 图片被发给了纯文本的 GLM-5.3：粘贴进主会话，或 vision 子代理被改到旗舰 | 按 11.0 图片落盘走 vision；确认**未设置** `CLAUDE_CODE_SUBAGENT_MODEL`（含 shell 残留），`/tasks` 核对 vision 实际模型 |
| vision 子代理未被自动委派 | 主线未识别任务的视觉属性 | `@vision` 显式点名；任务描述中给出图片路径；核对 `agents/vision.md` 部署路径与 frontmatter `description` |
| vision 转录细节缺失/读数模糊 | 两级压缩（客户端缩放重编码 + 服务端换算） | 按 11.0 先裁剪感兴趣区域再读；下达任务时指明关注区域 |
| vision 子代理读图本身报错 | Anthropic 端点 image 内容块环节异常（官方未单独文档化，见 7.13） | 回退 Vision MCP（11.3）应急；在 Z.AI 官方渠道确认端点图片支持状态后更新 7.13/11.0 的口径 |
| Vision MCP 秒断 | Node<22 / npx 缓存旧版 / Key 未配置 | `node -v`；`@latest`；裸跑测试；[Vision MCP](https://docs.z.ai/devpack/mcp/vision-mcp-server) |
| 三个远程 MCP 集体失效 | 当月共享 4000 次配额用尽或 Key 失效 | 控制台查用量；切换账号或等待下月；[Overview](https://docs.z.ai/devpack/overview) |
| "忘记前文" | 窗口按 200K 误判，或已发生压缩而关键信息未落盘 | `/context` 核对窗口与占用；确认 `[1m]`/水位 800K 生效；已压缩则重读 worklog/报告文件（9.4），fullscreen 下 `Ctrl+Home` 回滚原文（7.12） |
| 会话逼近 1M 后卡死：手动/自动压缩均失败、每轮请求报错 | 压缩水位曾设为满格 1M：压缩请求（全部历史+摘要指令+131K 输出预留）自身超出模型上限被拒；自动压缩失败 3 次熔断；网关报错文案不被识别、无错误触发式恢复 | 本配置已将水位降至 800000（7.4.0 机制详解），新会话不再触达死区。存量卡死会话：先试 `/rewind` → Summarize up to here 部分摘要（请求更小），仍失败则导出 + 新会话 + worklog 再引导（9.4 兜底路径） |
| 压缩后关键结论/数字丢失 | 压缩摘要未保留该信息且未落盘 | 按 9.4 规程：阶段结论先落盘再压缩；CLAUDE.md 写入"压缩保留项"（9.2/10.3 模板已含）；金融数字不得凭摘要复述，重新取数（10.4） |
| WebFetch 全部失败 | 未跳过 Anthropic 预检 | `skipWebFetchPreflight: true`；[Settings](https://code.claude.com/docs/en/settings) |
| 内置 WebSearch 报错 | Anthropic 服务端工具，网关不可用 | 使用 web-search-prime；[Tools reference](https://code.claude.com/docs/en/tools-reference) |
| 非 bypass 模式弹出权限窗 | 工具不在 allow / 拼写非权威名 | 对照 7.9 清单；`/permissions` 查看规则来源 |
| 5 小时窗口触顶 | MAX 档亦有窗口配额 | 按第 12 章切换账号，任务不降级续跑 |
| 后台子代理异常标记 "failed" | 长命令期间无进度事件被判失速 | 已放宽到 1h；超过 1h 的构建改用后台命令执行；[env-vars（`CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS`）](https://code.claude.com/docs/en/env-vars) |
| `/effort` 未提示被环境变量接管 / 疑似 effort 未生效 | 能力声明或 `CLAUDE_CODE_ALWAYS_ENABLE_EFFORT` 未生效 | 核对 `_SUPPORTED_CAPABILITIES` 与 `CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1`；重启会话；`/status` 查看设置来源 |
| 无人值守的深度分析 10 分钟被终止 | headless 后台等待上限默认 10 分钟 | 本配置已设 `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0`（无限等待）；核对 `/status` 设置来源；[env-vars](https://code.claude.com/docs/en/env-vars) |
| `-p` 提示词中写了 ultracode 却没有 workflow | 关键词仅对人工输入生效 | 使用 `claude --effort ultracode -p`（10.5 轨道二）；[Workflows](https://code.claude.com/docs/en/workflows) |
| `ultracode` 不触发 workflow | 锁定档不是 `xhigh`，或 workflows 被关闭 | 确认 `CLAUDE_CODE_EFFORT_LEVEL=xhigh`（见 7.3）；确认未设 `disableWorkflows`；[Workflows](https://code.claude.com/docs/en/workflows) |
| workflow 编排的代理数总在十几个封顶 | `workflowSizeGuideline` 处于默认 `medium`（<15 引导） | 确认已设 `unrestricted` 且未被项目级设置覆盖（设置文件值会让 /config 行隐藏，见 7.10）；[Workflows – size guideline](https://code.claude.com/docs/en/workflows) |
| 全屏渲染出现残影/错位碎片 | Windows Terminal（ConPTY）增量重绘合并缺陷 | 确认 `CLAUDE_CODE_ALT_SCREEN_FULL_REPAINT=1` 生效（7.12）；滚动出空白块再叠加 `CLAUDE_CODE_DISABLE_VIRTUAL_SCROLL=1`；临时回退 `/tui default`；[Fullscreen – Troubleshooting](https://code.claude.com/docs/en/fullscreen) |
| 子代理 spawn 报 `Subagent spawn limit reached` | CLI < v2.1.224，旧的 200 总量上限仍在 | `claude --version` ≥ 2.1.233（17.2）；v2.1.224 起总量上限已移除，现行约束为并发 20/深度 3（7.10），超出部分排队而非拒绝 |
| 任务清单工具（TaskCreate 等）不可用 | CLI ≥ 2.1.233 且模型被判为"较新"，默认移除 | 确认 `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` 生效（7.10）；[env-vars](https://code.claude.com/docs/en/env-vars) |

---

# 第五部分：附录

## 17. GLM-5.3 迁移说明与版本门槛

### 17.1 GLM-5.3 迁移说明

GLM-5.3 与 GLM-5.2 基座完全相同，提升全部来自后训练（数十倍规模的长程任务环境与超长周期训练）：编程体感提升 50%，Terminal-Bench 3.0 从 4.6 提升至 28.3，DeepSWE v1.1 从 46.2 提升至 66.9，Agents' Last Exam 从 23.8 提升至 28.5——直接强化本手册两大场景的核心能力（长程工程执行、多步取证）。模型规格（1M 上下文 / 128K 最大输出）与全部接入机制（`[1m]` 后缀用法、effort 映射）与 5.2 完全一致，迁移不涉及任何机制调整。

迁移的必要性：GLM-5.3 已在 Coding Plan 全套餐（Max/Pro/Lite）上线，Z.AI Anthropic 端点的允许模型列表为 "GLM-5.3, GLM-5-Turbo and GLM-4.7"——GLM-5.2 已不在列，继续使用将触发 1113 或模型不存在错误。升级是兼容性必需，而非可选项。

迁移内容：四个别名位整体由 `glm-5.2[1m]` / `glm-5.2` 迁移至 `glm-5.3[1m]` / `glm-5.3`，显示名同步，其余参数零改动。两处明示的设计决策：

| 决策点 | 取舍 | 理由 |
| --- | --- | --- |
| Haiku 位模型 | 维持 `glm-5.3` 裸名，不采用官方切换示例的 `glm-4.7` | 第 3 章"全链路单旗舰"原则；`[1m]` 后缀在 Haiku 位无官方文档保证且后台任务极短，故用裸模型名 |
| 采样标定 | 沿用 GLM-5.2 迁移指南的默认值（`temperature=1.0` / `top_p=0.95`） | 5.3 与 5.2 同基座，标定沿用；且第 8 章本就不注入采样参数，无实际影响 |

部署与验证：迁移后按第 15 章清单验证，`/status` 应显示 `glm-5.3[1m]`。若报模型不存在或 1113（文档与线上状态可能存在时间差），先将 CLI 升级至最新再试（`[1m]` 后缀解析依赖新版）。模型名的任何回改均属行为漂移，仅在任务边界执行（第 14 章）。

- 来源：[Z.AI – How to Switch Models（`glm-5.3[1m]` 示例与 effort 映射）](https://docs.z.ai/devpack/latest-model)、[Z.AI – FAQ（端点允许模型列表）](https://docs.z.ai/devpack/faq)、[智谱开放平台 – GLM-5.3（发布规格与基准）](https://docs.bigmodel.cn/cn/guide/models/text/glm-5.3)

### 17.2 版本门槛备查表

| 变量（本配置值） | 最低版本 | 旧版行为 |
| --- | --- | --- |
| `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` | v2.1.233 | 无此变量；较新模型判定下任务清单工具缺失 |
| `workflowSizeGuideline=unrestricted`（设置键） | v2.1.219 | 旧版忽略该键；v2.1.219–2.1.218 间内置默认为 unrestricted，2.1.219 起改为 `medium`（<15 引导）——本配置显式设值即对冲该默认 |
| `CLAUDE_CODE_FORK_SUBAGENT=1` 在 `-p` 下生效 | v2.1.232 | 旧版 `-p` 下 fork 同样需显式置 1，语义一致；v2.1.232 起交互会话默认启用 |
| `CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS=0` | v2.1.212 | 静默回退 2 分钟自动转后台 |
| `CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT=600000` | v2.1.187 | 走传输层默认（网络 5 分钟/stdio 30 分钟） |
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS` 对自定义模型名直接生效 | v2.1.193 | 需配合其他条件 |
| `CLAUDE_CODE_RETRY_WATCHDOG=1`（含 v2.1.239 计费类 429 立即失败语义） | v2.1.186 | 无看门狗语义，按默认重试 |
| 子代理 frontmatter `model` 指定完整模型 ID + 解析优先级现行语义（vision 路由的机制基础） | v2.1.196+（`SUBAGENT_MODEL=inherit` 等价不设） | 更旧版本 inherit 语义不同 |
| `--effort ultracode` 启动参数 | v2.1.203 | 报 Unknown value（会话内 `/effort ultracode` 不受此限） |
| ~~`CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION=1000`~~ | — | **已移除**：v2.1.224 起该变量为 no-op（官方移除单会话 200 总量上限），配置与手册同步删除，现行约束见 7.10 |

第 13 章的升级纪律（保持最新 CLI）本身即是对这张表的最佳防御。`claude --version` ≥ v2.1.233 即全部满足；`minimumVersion: "2.1.233"`（7.11）已把该门槛固化为启动检查——切换发布通道降级到门槛以下会直接拒绝运行，而非静默回退。使用者当前环境为 v2.1.250（v2.1.247–250 区间配置零改动：无新采用键，新增键均判不适用，取舍见第 8 章；2.1.249 未发布，2.1.250 整版仅可靠性修复）。
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
- Agent view / 后台会话（`--bg`/`claude agents`/attach）：<https://code.claude.com/docs/en/agent-view>
- 全屏渲染（fullscreen/滚动/检索/ConPTY 修复）：<https://code.claude.com/docs/en/fullscreen>
- 终端配置（铃声通知/Shift+Enter/主题/键位）：<https://code.claude.com/docs/en/terminal-config>
- Fast mode（网关下不适用，备查）：<https://code.claude.com/docs/en/fast-mode>
- 状态栏（statusline 字段与 Windows 配置）：<https://code.claude.com/docs/en/statusline>
- 记忆机制（CLAUDE.md/规则/auto memory）：<https://code.claude.com/docs/en/memory>
- 超大代码库/monorepo 专文：<https://code.claude.com/docs/en/large-codebases>
- 上下文窗口机制（压缩存活表/水位/`/context`）：<https://code.claude.com/docs/en/context-window>
- 官方最佳实践（上下文为首要约束/`/clear`/`/btw`/反模式清单）：<https://code.claude.com/docs/en/best-practices>

**长上下文质量权威研究（7.4.0 定调依据）**

- Anthropic 工程博客 – Effective context engineering for AI agents（context rot/注意力预算/长程三板斧）：<https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents>
- Chroma – Context Rot 技术报告（18 模型受控实验）：<https://research.trychroma.com/context-rot>
- NoLiMa: Long-Context Evaluation Beyond Literal Matching（ICML 2025）：<https://arxiv.org/abs/2502.05167>
- RULER: What's the Real Context Size of Your Long-Context Language Models?（COLM 2024）：<https://arxiv.org/abs/2404.06654>

**Z.AI 官方文档**

- 开发者文档首页：<https://docs.z.ai>
- GLM-5.3 模型页（"text-only inputs"、1M/128K 规格）：<https://docs.z.ai/guides/llm/glm-5.3>
- GLM-5.3-Flash 模型页（原生多模态、image_url 用法、推荐参数）：<https://docs.z.ai/guides/vlm/glm-5.3-flash>
- Z.ai 官方博客 – GLM-5.3（旗舰基准全表）：<https://z.ai/blog/glm-5.3>
- 智谱开放平台 – GLM-5.3-Flash（Flash 基准表与 AA 指数）：<https://docs.bigmodel.cn/cn/guide/models/vlm/glm-5.3-flash>
- 定价总览（GLM-5.3 / 5.3-Flash）：<https://docs.z.ai/guides/overview/pricing>
- Coding Plan 总览（配额/倍率/专属 MCP）：<https://docs.z.ai/devpack/overview>
- 快速开始（端点表）：<https://docs.z.ai/devpack/quick-start>
- Claude Code 接入：<https://docs.z.ai/devpack/tool/claude>
- 切换 GLM-5.3 / 1M / effort 映射：<https://docs.z.ai/devpack/latest-model>
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
- 智谱开放平台 – GLM-5.3 模型说明（发布规格与基准）：<https://docs.bigmodel.cn/cn/guide/models/text/glm-5.3>

> 领域作业规程说明：第 9、10 章中 BMC 工程实践与 A 股交易规则/口径清单（T+1、分板块涨跌停幅度、复权、报告期 vs 公告日、point-in-time 等）为领域专家经验层，不出自上述两个文档站；使用前请按实际标的与最新交易所规则校验（新股、退市整理期等特殊证券的规则随监管调整）。
