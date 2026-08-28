# GLM-5.3-Flash × Claude Code（Windows）产能型专项手册

> **定位**：本手册是 glm-settings 仓库的 **`glm-5.3-flash` 专项分支**，面向"高强度并行开发 + 视觉密集 + 长时间高频使用"的产能型工况。仓库 main 分支（旗舰版）面向"单任务最深推理"的极致工况；两者是分工关系而非优劣关系（见第 2 章）。
>
> **总原则**：正确性、完备性、可靠性仍是不可让渡的底线；在此之上，本分支的第一设计目标是**吞吐**——把 GLM-5.3-Flash"配额消耗约为旗舰 1/3、原生多模态、次旗舰代码能力"的三重优势转化为可度量的产能（单位时间完成的任务量、单窗口可推进的并行规模、无需切换模型的视觉闭环）。
>
> **适用环境**：Windows 原生 Claude Code CLI（v2.1.250 时点）+ Z.AI GLM Coding Plan MAX（多账号轮换备而少用）。
> **文档快照日期**：2026-08-28。机制性结论以 [Claude Code Docs](https://code.claude.com/docs/en/overview) 与 [Z.AI Docs](https://docs.z.ai) 为准；模型能力结论以 Z.ai/智谱官方发布口径为准（含口径声明，见第 1 章）；作业规程为专家经验层。

---

## 目录

- **第一部分：选型论证——为什么是 Flash**
  - 1. 四大支柱（官方依据）
  - 2. 边界、口径与 main 的分工
  - 3. 场景需求规格
  - 4. 需求 → 配置追溯矩阵
- **第二部分：配置**
  - 5. 工作原理速览
  - 6. 配置文件位置、部署与验证
  - 7. 参数逐项详解（附权威来源）
  - 8. 多模态主线：图片作业规程
  - 9. 有意不设置的参数及原因
- **第三部分：作业手册**
  - 10. 场景 ①：BMC 级代码体系的高强度并行开发
  - 11. 场景 ②：A 股例行分析（产能轨）
  - 12. 场景 ③：视觉密集工作流
- **第四部分：运维**
  - 13. 5 小时窗口与配额策略
  - 14. 专属 MCP 部署
  - 15. 升级 SOP
  - 16. 一致性管理：行为漂移源清单
  - 17. 部署后验证清单
  - 18. 故障排查速查表
- **第五部分：附录**
  - 19. 基准数据备查
  - 20. 版本门槛备查表
  - 21. 参考链接汇总

---

# 第一部分：选型论证——为什么是 Flash

## 1. 四大支柱（官方依据）

### 1.1 支柱一：次旗舰的代码能力——"复杂代码开发"的胜任线之上

Z.ai/智谱官方发布口径（厂商自报、自跑 harness；Terminal-Bench 官方验证榜 tbench.ai 尚无 5.3 系条目，采信时须知此限，见第 2 章）：

| Code Agent 基准 | GLM-5.3-Flash | GLM-5.3（旗舰） | GLM-5.2 | Opus 4.8 | Gemini 3.7 Flash | DS-V4-Vision-Exp |
| --- | --- | --- | --- | --- | --- | --- |
| Terminal Bench 2.1 | 84.3 | **88.2** | 81.0 | 85.0 | 85.8 | 83.9 |
| DeepSWE v1.1 | **63.4** | 66.9 | 46.2 | 58.0 | 65.3 | 59.3 |
| Agents' Last Exam | 26.3 | **28.5** | 20.4 | 27.0 | — | 27.3 |
| AutomationBench | 48.8 | 48.2 | 26.2 | 41.0 | **52.3** | 38.8 |
| GDPval-AA v2 | **1773** | 1769 | 1504 | 1582 | 1527 | 1675 |
| HLE w/ Tools | 55.3 | — | 54.7 | **57.9** | — | 55.1 |
| Z.ai Code Bench（Max effort） | 29.0 | **34.5** | — | 29.5 | — | — |
| Artificial Analysis 智能指数 | 57 | **60** | 53 | 57 | — | — |

> 注：**加粗 = 行内最优**（客观标注，flash 的亮点在正文论述）。Agents' Last Exam 行的 GLM-5.2=20.4 与 Opus 4.8=27.0 取自 **Flash 官方图表口径**（同一张表内横比一致；GLM-5.2 在旗舰官方表为 23.8、Opus 4.8 为 25.7，见第 19 章双值标注）。

三个决定性读数：**DeepSWE v1.1 63.4 反超 Opus 4.8（58.0）**——真实仓库级多步工程任务上已越过 Opus 4.8；**AA 智能指数 57 与 Opus 4.8 持平**（bigmodel.cn 官方文档原文，AA 官网交叉确认）；Z.ai Code Bench Max effort 29.0 vs Opus 4.8 的 29.5（基本持平，且以更低的 token 消耗档位达成）。与自家旗舰的差距集中在 2–4 分（TB2.1 -3.9、DeepSWE -3.5、ALE -2.2）——见第 2 章的边界讨论。

### 1.2 支柱二：原生多模态——视觉进入编码循环

GLM-5.3-Flash 是 **"the first native multimodal model in the GLM-5 series"**（GLM-5 系列首个原生多模态模型），官方能力声明 "Native multimodal input supporting images, videos, and files"；而旗舰 GLM-5.3 官方明示 "currently supports text-only inputs"。对 Claude Code 工况的直接意义：

- **主线直接吃图**：报错截图、UI 走查、架构图、K 线图随对话发给主线模型即可，不需要任何"视觉路由"结构（子代理/别名位/MCP 桥接）——没有第二个模型，就没有路由失败面；
- **视觉融入编码循环**：官方对 flash 的定位描述即"视觉融入 coding 循环，可主动观察 UI/渲染结果迭代改进"——第 12 章把它落地为"改码 → 截图 → 主线看图比对 → 再改"的闭环工作流；
- **并行子代理同样看图**：子代理继承主线模型，fork/workflow 的每一路都具备视觉——批量截图审查（CI 失败截图墙、多页面 UI 走查）成为天然的大规模并行任务。

### 1.3 支柱三：配额吞吐——同样的 5 小时窗口，3 倍的任务容量

智谱官方对 flash 在 Coding Plan 中的定位：**3 倍额度**（单个 prompt 的配额消耗约为旗舰的 1/3）。折算（推算口径，非官方直接数字）：MAX 档 5 小时窗口约 1600 旗舰 prompts（官方套餐口径），flash 等效容量约 **4800 prompts/5h**；周配额同理 3 倍。对产能工况的含义：

- 高强度使用下"触顶 → 切换账号/等窗口"的中断频率降为约 1/3——多账号轮换从日常机制降级为备用机制（第 13 章）；
- 大规模并行（几十上百子代理的 workflow）不再显著侵蚀窗口寿命——并行规模与配额寿命第一次可以同时拉满；
- 这是本分支把客户端并发上限知情上调（7.10：子代理并发 40、工具并发 20）的物质基础。

### 1.4 支柱四：API 价格（按量场景的并行规模上限）

API 直调价格约为旗舰 1/10（限时促销约 1/18–1/20，至 2026-09-09：输入 $0.075 / 输出 $0.25 每百万 token；旗舰 $1.4 / $4.4；缓存输入 $0.015）。本手册总原则仍是"成本不入决策"，但价格在此处的意义不是省钱，而是**按量计费场景下并行规模的天花板被抬高一个量级**——同样预算可支撑 10–20 倍的子代理总 token 量，使"用并行换正确性"（多路核查、对抗互验）在按量场景也成为常规手段而非奢侈选项。

## 2. 边界、口径与 main 的分工

### 2.1 口径声明（必须随表携带）

1. 上表全部数字为 **Z.ai/智谱官方自报**（自跑 harness、自家择定的基准集）；Terminal-Bench 2.1 官方验证榜（tbench.ai）目前无任何 GLM-5.3/5.3-Flash 条目（唯一 GLM 条目是 GLM-5.1 @ 58.7），SWE-bench Verified、LiveCodeBench、Aider Polyglot 在 5.3 世代均无官方数据。**跨厂商横比只能作方向参考，不能作工程承诺**。
2. 官方自跑与官方验证榜的 harness 差异（Claude Code 版本、容器配置、max effort 档）会使绝对分数系统性偏移——本手册只在**同一张官方表内部**做相对比较（flash vs 旗舰 vs Opus 4.8 同表同 harness）。

### 2.2 能力边界（知情取舍）

- **极限长时程 agent 任务无数据**：TB3.0（旗舰 28.3 vs 5.2 的 4.6）、FrontierSWE（78.1）、SWE-Marathon（42.5）只有旗舰成绩，flash 未公布。"数十小时级自主马拉松任务"是旗舰后训练的独占地带，本分支对此是**知情放弃**而非已知胜任。
- 与旗舰 2–4 分的稳定差距在"每个环节都要最强推理"的任务里会复利放大——这类任务不该用本分支。

### 2.3 分工矩阵

| 任务形态 | 用哪套 | 判据 |
| --- | --- | --- |
| 日常开发、批量迁移、全仓审计、大规模并行重构 | **本分支** | DeepSWE 63.4 已过 Opus 4.8 线；并行规模与配额寿命是本分支独有优势 |
| UI 前端迭代、截图密集调试、图表/研报读数 | **本分支** | 主线原生多模态，零路由闭环（第 12 章） |
| 盘后例行分析、数据管道、可复跑轨道 | **本分支** | 结构稳定 + 高频 + 无人值守，3× 窗口容量直接放大日产能 |
| 架构级攻坚、跨栈深度推理、关键算法设计 | **main（旗舰）** | 全基准领先 + 手册"最强模型"哲学 |
| 极限长时程自主任务（TB3.0 类） | **main（旗舰）** | flash 无公布成绩 |
| A 股重大专题（季度复盘、拐点判定） | **main（旗舰）** | B 类需求的最深多空核查不留次优推理 |
| 两套并行使用 | 各开各的会话 | 切换 = 行为漂移，只在任务边界执行（第 16 章） |

## 3. 场景需求规格

三个场景反推的硬需求（编号 A1–A6 / B1–B5 / C1–C4，第 4 章给出逐条追溯）：

### 3.1 场景 ①：BMC 级代码体系的高强度并行开发（产能轨）

BMC 全栈（Yocto/bitbake、u-boot、内核驱动、设备树、phosphor-* D-Bus 服务、bmcweb/Redfish、WebUI）的日常开发与批量改造，主打**量**——批量迁移、全仓审计、多模块并行改造（单点最深推理走 main，见第 2 章）。

| 编号 | 需求 | 判定标准 |
| --- | --- | --- |
| **A1 跨栈上下文** | 单任务推理容纳多仓库多语言代码与工程约定 | 1M 窗口全程可用且压缩永不失败（水位受控）；多目录 CLAUDE.md 全载入；巨型源码树检索不超时 |
| **A2 高强度并行** | 几十上百子代理并行审计/迁移时，排队时间与配额消耗最小化 | 子代理并发上限知情上调；workflow 规模无引导上限；fork/worktree/agent teams 全启用 |
| **A3 证据先行** | 协议字段、寄存器位、接口签名必须来自读到的真实代码 | 工具输出与子代理回传在上限内不截断；上游仓库可直接检索 |
| **A4 规范硬约束** | 禁改区、许可证边界、构建验证闭环强制执行 | CLAUDE.md 硬规则 + 验证闭环命令化 |
| **A5 长周期执行** | 小时级构建与多阶段迁移中任何环节不得静默中断 | 全套看门狗、重试、headless 无限等待 |
| **A6 行为一致性** | 任务内模型/档位/工具集不漂移 | 单模型 + effort 环境变量锁定 + 漂移源清单 |

### 3.2 场景 ②：A 股例行分析（产能轨）

每日例行 + 周度专题的**高频、结构稳定、无人值守**分析（11.4 双轨）。重大专题（对抗互验深核查）按第 2 章分工走 main。

| 编号 | 需求 | 判定标准 |
| --- | --- | --- |
| **B1 数据值绝对可靠** | 每个数字来自当轮工具调用并可溯源 | 检索/读页链路全程可用不截断；数字带来源与时间 |
| **B2 口径先于计算** | 复权、单位、报告期、交易日历先锁定再计算 | CLAUDE.md 口径声明规程 |
| **B3 无人值守复跑** | 盘后任务计划程序自动执行、产物落盘可审计 | bypass + 看门狗 + headless 无限等待 + 铃声闭环 |
| **B4 推理可审** | 结论的中间推理可见可复查 | 思考全程开启 + transcript 检索 |
| **B5 窗口寿命** | 高频例行不因 5h 配额触顶而中断 | flash 3× 容量 + 触顶处置预案（第 13 章） |

### 3.3 场景 ③：视觉密集工作流

Debug 截图诊断、前端 UI 迭代走查、架构图/时序图理解、K 线与研报图表读数——主线原生多模态是其独有支点。

| 编号 | 需求 | 判定标准 |
| --- | --- | --- |
| **C1 主线吃图** | 图片直接进主会话（粘贴/Read），无路由结构、无第二模型 | Anthropic 端点 image 块验证通过（第 17 章第 8 条） |
| **C2 转录可靠性** | 图片转文字可审计：转录先行、裁剪保全、不确定性明示 | 图片作业规程（第 8 章）写入肌肉记忆与 CLAUDE.md |
| **C3 视觉融入循环** | 改码→截图→比对→再改的单会话闭环 | 第 12 章工作流；截图落盘命名规程 |
| **C4 并行视觉** | 批量截图审查可大规模并行 | 子代理继承主线视觉能力（A2 的并发上调同时服务于此） |

## 4. 需求 → 配置追溯矩阵

| 需求 | 对应配置/机制 | 详解章节 |
| --- | --- | --- |
| A1 跨栈上下文 | 四别名位全 flash（三位 `glm-5.3-flash[1m]` + Haiku 裸名，窗口由 `CLAUDE_CODE_MAX_CONTEXT_TOKENS` 兜底）、`CLAUDE_CODE_AUTO_COMPACT_WINDOW=800000`、`CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1`、`CLAUDE_CODE_GLOB_TIMEOUT_SECONDS=60` | 7.2 / 7.4 |
| A2 高强度并行 | `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=40`、`CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=20`、`workflowSizeGuideline=unrestricted`、`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`、`CLAUDE_CODE_FORK_SUBAGENT=1` | 7.10 |
| A3 证据先行 | `BASH_MAX_OUTPUT_LENGTH=150000`、`TASK_MAX_OUTPUT_LENGTH=160000`、`CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS=65536`、`MAX_MCP_OUTPUT_TOKENS=50000`、Zread/Web Reader MCP | 7.5 / 14 |
| A4 规范硬约束 | CLAUDE.md 模板（10.2）、验证闭环规程 | 10 |
| A5 长周期执行 | `API_TIMEOUT_MS=3000000`、`API_FORCE_IDLE_TIMEOUT=0`、`CLAUDE_STREAM_IDLE_TIMEOUT_MS=1800000`、`CLAUDE_CODE_RETRY_WATCHDOG=1`、`BASH_MAX_TIMEOUT_MS=3600000`、`CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS=3600000`、`CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0` | 7.6 / 7.10 |
| A6 行为一致性 | 单模型全链路、effort 环境变量锁定 xhigh、不设 fallback、升级 SOP、漂移源清单 | 5 / 7.3 / 15 / 16 |
| B1 数据可靠 | 四个 Z.AI MCP + `skipWebFetchPreflight`、数据铁律（11.2） | 11 / 14 |
| B2 口径时点 | A 股 CLAUDE.md 模板（11.3） | 11 |
| B3 无人值守 | bypassPermissions、重试看门狗、headless 双轨（11.4）、`preferredNotifChannel=terminal_bell`、`minimumVersion=2.1.233` | 7.9 / 7.6 / 11 |
| B4 推理可审 | `alwaysThinkingEnabled`、`showThinkingSummaries`、fullscreen + `Ctrl+O` | 7.3 / 7.12 |
| B5 窗口寿命 | flash 3× 配额容量（机制层无配置）、触顶预案 | 13 |
| C1 主线吃图 | 主线 = 原生多模态模型（无配置键，架构性达成）；验证点与回退 | 8 / 17 / 18 |
| C2 转录可靠 | 图片作业规程（裁剪、转录先行、不确定性标注） | 8 |
| C3 视觉循环 | 截图落盘命名 + 单会话迭代工作流 | 12 |
| C4 并行视觉 | 子代理 inherit 主线视觉 + A2 并发上调 | 7.10 / 12 |

---

# 第二部分：配置

## 5. 工作原理速览

### 5.1 网关模式

Claude Code 通过 `ANTHROPIC_BASE_URL` 将全部模型请求改发至兼容 Anthropic Messages 协议的端点；该变量仅改变"请求发往何处"。Z.AI Coding Plan 的 Anthropic 协议专属端点为 `https://api.z.ai/api/anthropic`（使用普通 API 端点会脱离套餐计费并产生 1113 余额错误）。

- 来源：[Claude Code – Model configuration](https://code.claude.com/docs/en/model-config)、[Z.AI – Quick Start（Endpoint Guide）](https://docs.z.ai/devpack/quick-start)、[Z.AI – FAQ](https://docs.z.ai/devpack/faq)

### 5.2 别名映射与 effort 映射

四个别名位（opus/sonnet/fable/haiku）由 `ANTHROPIC_DEFAULT_*_MODEL` 解析，本分支全部指向 flash（7.2）。Claude Code 的 effort 档位经 Z.AI 端点映射为 flash 的 `reasoning_effort`：

| Claude Code effort | GLM-5.3-Flash reasoning_effort |
| --- | --- |
| `low` / `medium` / `high` | `high` |
| `xhigh` / `max` / `ultracode` | **`max`**（flash 的最深推理档，也是其 API 默认值；官方编码任务推荐 max） |

flash 与旗舰同表：`reasoning_effort` 取值 low/high/max、默认 max；`thinking.type` 仅支持 `enabled`（思考不可关闭）——本配置锁定 xhigh 即 max，无任何档位损失。

- 来源：[Z.AI – How to Switch Models（映射表）](https://docs.z.ai/devpack/latest-model)、[Z.AI – GLM-5.3-Flash（推荐参数）](https://docs.z.ai/guides/vlm/glm-5.3-flash)

### 5.3 多模态路径（本分支的结构性简化）

图片输入走**主线本身**：输入框粘贴、Read 工具读图，均以 image 内容块随请求发给 glm-5.3-flash——没有视觉子代理、没有别名位桥接、没有 MCP 中转，零路由失败面；代价是主线窗口承载图片 token（作业规程见第 8 章，裁剪与落盘纪律对冲）。**唯一待验证环节**：Z.AI 官方将 flash 的图片输入文档化于 OpenAI 格式（`image_url`，支持 URL 与 Base64 Data URL），Anthropic 端点对 image 内容块的转换未单独声明——列为部署验证点（第 17 章第 8 条），失败回退 Vision MCP（第 14/18 章）。

- 来源：[Z.AI – GLM-5.3-Flash（image_url 用法）](https://docs.z.ai/guides/vlm/glm-5.3-flash)、[Z.AI – Claude Code 接入（官方示例含 `glm-5.3-flash[1m]`）](https://docs.z.ai/devpack/tool/claude)

### 5.4 两层缓存（背景知识）

Claude Code 侧为前缀精确匹配的提示缓存；Z.AI 侧为隐式自动缓存（`usage.prompt_tokens_details.cached_tokens` 可见），Coding Plan 端点默认开启 Preserved Thinking。缓存是无损机制，保持默认开启即可，不刻意追求也不防范。

## 6. 配置文件位置、部署与验证

| 作用域 | Windows 路径 | 影响范围 |
| --- | --- | --- |
| **用户级（本配置使用）** | `%USERPROFILE%\.claude\settings.json` | 当前用户、所有项目 |
| 项目级（共享/本地） | `<项目>\.claude\settings.json` / `settings.local.json` | 该仓库 |
| 托管策略 | `C:\Program Files\ClaudeCode\managed-settings.json` 等 | 全机器，最高优先级 |

要点：优先级 托管 > 命令行 > 项目本地 > 项目共享 > 用户级；数组类设置跨作用域合并；环境变量优先于设置字段，`env` 块优先于 shell 同名变量——一切变量集中于 `env` 块；settings 热加载大部分键，`model` 等下次启动生效。

部署步骤：

1. 将本分支 [`settings.json`](./settings.json) 部署至 `%USERPROFILE%\.claude\settings.json`，替换 `ANTHROPIC_AUTH_TOKEN` 为实际 Z.AI API Key。
2. **删除** `%USERPROFILE%\.claude\agents\vision.md`（若存在）——本架构无视觉子代理，残留的 vision.md（无论指向哪个模型）都会引入错误的委派路径。
3. 关闭全部既有会话后重启 `claude`，按第 17 章清单验证（重点：第 3 条显示名、第 8 条主线吃图）。

安全提示：settings.json 含明文 API Key，外发/截图/公开提交前必须移除；已暴露的 Key 立即在 Z.AI 控制台轮换。

- 来源：[Claude Code – Settings](https://code.claude.com/docs/en/settings)、[Claude Code – env-vars（Precedence）](https://code.claude.com/docs/en/env-vars)

## 7. 参数逐项详解

除特别说明外，`env` 值一律为字符串。

### 7.1 接入与认证

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.ANTHROPIC_BASE_URL` | `https://api.z.ai/api/anthropic` | Coding Plan 专属 Anthropic 协议端点，结尾不带 `/`。 |
| `env.ANTHROPIC_AUTH_TOKEN` | 使用者的 Z.AI API Key | 以 `Authorization: Bearer` 发送；系统中不得残留 `ANTHROPIC_API_KEY`，避免双认证冲突。 |

### 7.2 模型矩阵（全 Flash）

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.ANTHROPIC_DEFAULT_OPUS_MODEL` | `glm-5.3-flash[1m]` | 主力位。`[1m]` 使 Claude Code 按 1M 窗口管理会话，发送前自动剥除后缀；`glm-5.3-flash[1m]` 为端点合法字符串（官方 Claude Code 示例使用）。 |
| `env.ANTHROPIC_DEFAULT_SONNET_MODEL` | `glm-5.3-flash[1m]` | 覆盖一切解析到 sonnet 的路径（含 `opusplan` 执行阶段）。 |
| `env.ANTHROPIC_DEFAULT_FABLE_MODEL` | `glm-5.3-flash[1m]` | 覆盖 `fable`/`best` 别名路径。 |
| `env.ANTHROPIC_DEFAULT_HAIKU_MODEL` | `glm-5.3-flash` | 后台辅助功能（标题、WebFetch 抽取）。`[1m]` 后缀官方仅对 Opus/Sonnet 位提供文档保证，后台任务极短，用裸名；`CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000` 对裸名自定义 ID 直接生效（v2.1.193+）兜底窗口。 |
| `env.CLAUDE_CODE_SUBAGENT_MODEL` | `opus` | 强制所有子代理/agent teams/workflow 代理走 opus 别名（=flash[1m]），并覆盖任何子代理定义试图指定的其他模型——全链路单模型的行为学保证（A6）。本分支无需要 frontmatter 生效的专用子代理，此变量零副作用。 |
| `model`（顶层） | `opus` | 会话启动模型显式声明，杜绝默认值漂移。 |
| `env.ANTHROPIC_DEFAULT_*_MODEL_NAME` / `_DESCRIPTION` | `GLM-5.3-Flash (1M)` 等 | `/model` 选择器显示名。键位布局：Opus/Sonnet/Haiku 三位有 `_NAME`、仅 Opus 位有 `_DESCRIPTION`（Fable 位官方未提供此二键的示例，别名位显示名以三位为限）——不对称是官方边界内的有意布局。 |
| `env.ANTHROPIC_DEFAULT_*_MODEL_SUPPORTED_CAPABILITIES` | `effort,xhigh_effort,max_effort,thinking,adaptive_thinking,interleaved_thinking`（四位一致） | 声明自定义模型能力，解锁 effort 滑杆、xhigh/max 档、思考渲染、工具间思考。 |

### 7.3 思考深度：锁定 reasoning_effort=max

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.CLAUDE_CODE_EFFORT_LEVEL` | `xhigh` | **锁定档**。环境变量是 effort 最高优先级来源（高于 `/effort` 与 `effortLevel`）；经映射 xhigh 即 flash 的 `reasoning_effort=max`，与 `max` 档推理深度无差别。锁 xhigh 而非 max 的原因：官方明确"当该变量设为 xhigh 以外档位时 ultracode 的 workflow 编排保持关闭"——锁 xhigh 以相同的最深推理保留 ultracode 自动编排通道（A2 大规模并行的主力通道）。 |
| `effortLevel`（顶层） | `xhigh` | 冗余保障层。 |
| `env.CLAUDE_CODE_ALWAYS_ENABLE_EFFORT` | `1` | 自定义模型 ID 下强制随请求发送 effort 参数（官方明示用于 LLM gateway/third-party provider 场景）。 |
| `alwaysThinkingEnabled` | `true` | 所有会话默认扩展思考（flash 思考本就不可关闭，此键保证客户端不发出关闭形态）。 |
| `showThinkingSummaries` | `true` | 思考可见（`Ctrl+O` 展开）——B4 推理可审。 |

### 7.4 上下文：1M 窗口 + 800K 压缩水位

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.CLAUDE_CODE_AUTO_COMPACT_WINDOW` | `800000` | 压缩水位。满格 1M 会使压缩请求自身（历史+摘要指令+131072 输出预留+思考开销）超出模型上限被拒，连续失败 3 次熔断后会话死锁；网关场景无"报错触发式恢复"（网关改写的报错文案不被识别）。800K 算术：压缩请求 ≈ 800K + 指令 + 131K ≈ 935K < 1M，留 ~65K 结构余量。可按任务在 700K–850K 调节，850K 以上禁入。 |
| `env.CLAUDE_CODE_MAX_CONTEXT_TOKENS` | `1000000` | 显式声明窗口；作用于裸名位与后缀解析异常兜底。 |
| `env.CLAUDE_CODE_MAX_OUTPUT_TOKENS` | `131072` | 单请求输出上限 = flash 最大输出 128K（官方口径"参数与 GLM-5.3 一致"）。与 800K 水位配套（调整任一须重算另一）。 |
| `env.CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD` | `1` | `/add-dir` 挂载目录的 CLAUDE.md/规则全部载入（多仓库工况）。 |
| `env.CLAUDE_CODE_GLOB_TIMEOUT_SECONDS` | `60` | Glob 超时 20s→60s（超大源码树检索不遗漏）。 |

长上下文质量定调：**1M 的价值是"单阶段容量"，不是"会话寿命"**——权威研究一致表明性能随填充度下降（context rot，远在名义上限之前）。会话寿命由证据落盘 + 阶段边界压缩 + `/clear` 再引导承担（10.3）。**多模态附加注意**：图片 token 计入主线窗口，视觉密集任务更应勤落盘、勤清段（第 8 章）。

- 来源：[Claude Code – Model configuration（压缩机制/网关恢复条款）](https://code.claude.com/docs/en/model-config)、[Anthropic – Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)、[Chroma – Context Rot](https://research.trychroma.com/context-rot)

### 7.5 证据不截断

| 参数 | 值 | 默认 | 含义与理由 |
| --- | --- | --- | --- |
| `env.CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` | `65536` | 较小值 | 单次文件读取 token 上限（长驱动/长财报整读）。 |
| `env.BASH_MAX_OUTPUT_LENGTH` | `150000` | 30000 | 命令输出入上下文上限（**官方硬上限**）。 |
| `env.MAX_MCP_OUTPUT_TOKENS` | `50000` | 25000 | MCP 响应上限（长网页/长源码不截断）。 |
| `env.TASK_MAX_OUTPUT_LENGTH` | `160000` | 32000 | 子代理回传上限（**官方最大值**）——并行审计结论是证据链核心载体。 |
| `env.BASH_DEFAULT_TIMEOUT_MS` | `600000` | 120000 | 命令默认超时 10 分钟。 |
| `env.BASH_MAX_TIMEOUT_MS` | `3600000` | 600000 | 命令超时上限 1 小时（bitbake 单包构建）。 |

### 7.6 传输可靠性

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.API_TIMEOUT_MS` | `3000000` | 单请求总超时 50 分钟（Z.AI 官方脚本值；max 档深思考最坏情况）。 |
| `env.API_FORCE_IDLE_TIMEOUT` | `0` | 关闭"流式 5 分钟无字节即中止"（深思考长停顿误杀源头）。 |
| `env.CLAUDE_STREAM_IDLE_TIMEOUT_MS` | `1800000` | 流式空闲看门狗 30 分钟（最终兜底）。 |
| `env.CLAUDE_ENABLE_BYTE_WATCHDOG` | `1` | 字节级看门狗（网关连接下默认关，显式开启；阈值复用上一变量）。 |
| `env.CLAUDE_CODE_RETRY_WATCHDOG` | `1` | 无人值守重试：429/529 容量类按限额重置时间退避；计费类 429 立即失败（v2.1.239 语义）。**注意**：本分支并发上调后 429 概率上升，此键是并发策略的安全网（7.10）。 |
| `env.CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK` | `1` | 禁止非流式回退重发（防工具重复执行）。 |
| `env.MCP_TIMEOUT` | `120000` | MCP 启动连接超时 2 分钟（Vision MCP npx 首拉）。 |
| `env.MCP_TOOL_TIMEOUT` | `1800000` | MCP 工具执行超时（同时提升 HTTP 型单请求 60s 上限）。 |
| `env.CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT` | `600000` | MCP 工具空闲判定 10 分钟。 |
| `env.CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS` | `0` | 关闭 2 分钟自动转后台（证据时序保证）。 |

### 7.7 提示词纯净

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.CLAUDE_CODE_ATTRIBUTION_HEADER` | `0` | 移除系统提示词版本指纹块（减噪；缓存收益附带）。 |

### 7.8 网络适配（无法直连 Anthropic 的环境）

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | `1` | 关闭自动更新/遥测/错误上报/发行说明/模型发现等非必要外联。 |
| `env.DISABLE_ERROR_REPORTING` / `env.DISABLE_TELEMETRY` | `1` / `1` | 显式双保险。 |
| `skipWebFetchPreflight`（顶层） | `true` | 跳过 WebFetch 对 api.anthropic.com 的域名预检（不跳过则 WebFetch 整体不可用）。 |
| `autoUpdatesChannel`（顶层） | `latest` | 手动升级跟最新通道。 |

已知自然结论：内置 WebSearch 为 Anthropic 服务端工具，网关下不可用——web-search-prime MCP 为正式替代（第 14 章）。

### 7.9 Windows 专项与自动化权限

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `env.CLAUDE_CODE_USE_POWERSHELL_TOOL` | `1` | 启用原生 PowerShell 工具（自动选 pwsh → powershell 回退，进程级 Bypass）。 |
| `defaultShell`（顶层） | `powershell` | `!` 手动命令走 PowerShell。 |
| `permissions.defaultMode` | `bypassPermissions` | 默认全自动（残留提示仅显式 ask 规则、requiresUserInteraction 的 MCP 工具、`rm -rf` 断路器）。 |
| `skipDangerousModePermissionPrompt` | `true` | 跳过进入 bypass 确认弹窗。 |
| `permissions.allow` | 20 条 | Shift+Tab 非 bypass 模式免批清单 + workflow 子代理的免批通行证（workflow 子代理强制 acceptEdits 并继承此清单）：`Bash`/`PowerShell`/`Read`/`Glob`/`Grep`/`LSP`/`Edit`/`Write`/`NotebookEdit`/`WebFetch`/`WebSearch`/`Agent`/`Skill`/`Monitor`/`EnterWorktree`/`Workflow` + 四个 `mcp__<server>`（14 章）。有意不放行 `ExitPlanMode`——计划审批保留人工闸门。 |
| `permissions.deny` | `[]` | deny 全模式生效，与全自动冲突，保持为空；实盘硬闸见 11.5（项目级窄 deny）。 |

### 7.10 高强度并行与长任务编排（本分支的核心差异章）

| 参数 | 值 | 默认 | 含义与理由 |
| --- | --- | --- | --- |
| `env.CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` | **`40`** | 20 | **知情上调 2×**，依据：① **配额容量 3×**（flash 消耗为旗舰 1/3，官方定位）——同样的 5h 窗口可容纳 3× 任务量，默认 20 成为人为瓶颈；② 429 无害化——`CLAUDE_CODE_RETRY_WATCHDOG` 对容量类 429 按限额重置时间退避重试，超发部分退化为排队而非失败（注意：按限额重置时间退避意味着等待可能以小时计——**429 密集出现本身即回落信号**，见第 18 章处置行）；③ 排队是纯时延损失——A2 场景（全仓审计、批量迁移、批量截图审查）的 spawn 超出并发的部分在默认值下大量排队。40 = 2× 默认，是对 3× 容量的**保守**映射（非满额 60），留出抖动余量。若实测 429 密集，回落 20。需 v2.1.217+。 |
| `env.CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY` | **`20`** | 10 | 同源上调：单轮并行工具调用的并发上限。flash 下多路取证（并行读文件+并行 MCP）更常触顶；429 安全网同上。 |
| `workflowSizeGuideline`（顶层） | `unrestricted` | medium | 官方默认 `medium` 引导 <15 代理的 workflow 规模——直接压制 A2；`unrestricted` 与 workflow 单 run 1000 代理上限对齐。 |
| `env.CLAUDE_CODE_ENABLE_TODO_TOOLS` | `1` | — | 任务清单工具显式锁定（v2.1.233 起较新模型默认不提供；长任务进度跟踪依赖它）。 |
| `env.CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS` | `3600000` | 600000 | 后台子代理失速判定 10 分钟→1 小时（长构建期间无进度事件不被误判）。 |
| `env.CLAUDE_CODE_FORK_SUBAGENT` | `1` | — | fork 子代理（继承完整上下文开分支）；交互会话 v2.1.232 起默认开，`-p`/SDK 下仍需显式置 1——无人值守轨道（11.4）必需。 |
| `env.CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS` | `0` | 600000 | headless 后台等待上限 10 分钟→无限（深度 workflow 不被隐蔽截断）。 |
| `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `1` | — | 实验性 agent teams；队友恒用 leader 模型（v2.1.234 起），别名位全对齐 + `CLAUDE_CODE_SUBAGENT_MODEL` 兜底，全链路 flash 双保险。异常时删除此行即可。 |
| 子代理嵌套深度 | 保持默认 3 | 3 | 深度调大导致上下文指数膨胀与结果不可汇聚，与并发不同维度，不动。 |
| workflow runtime 并发 | 保持内置 16 | 16 | workflow runtime 自身的单 run 并发上限为内置值，不受上述变量影响；40 的会话级并发服务于 agent teams/手动 fan-out/多会话叠加。 |

- 来源：[Claude Code – env-vars（`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`、`CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY`、`CLAUDE_CODE_RETRY_WATCHDOG` 等）](https://code.claude.com/docs/en/env-vars)、[Claude Code – Workflows（规模/单 run 上限）](https://code.claude.com/docs/en/workflows)、[Z.AI – Coding Plan（flash 3× 额度定位）](https://docs.z.ai/devpack/overview)

### 7.11 留痕与其他

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `cleanupPeriodDays` | `365` | 会话转录保留一年（审计底稿）。 |
| `attribution.commit`/`attribution.pr` | `""`/`""` | 关闭提交/PR 署名。 |
| `language` | `chinese-simplified` | 默认中文。 |
| `minimumVersion` | `2.1.233` | 版本门槛硬执行（第 20 章）；低于门槛拒绝启动而非静默回退。 |
| `$schema` | schemastore | 编辑器校验。 |

### 7.12 终端渲染与通知

| 参数 | 值 | 含义与理由 |
| --- | --- | --- |
| `tui`（顶层） | `fullscreen` | 内存恒定（长会话不随转录增长吃内存）、压缩后全量回滚（`Ctrl+Home`）、大输出折叠交互、`Ctrl+O` transcript 检索。 |
| `env.CLAUDE_CODE_ALT_SCREEN_FULL_REPAINT` | `1` | Windows ConPTY 增量重绘残影修复（全帧重绘）。 |
| `preferredNotifChannel`（顶层） | `terminal_bell` | 完成通知闭环（Windows Terminal 默认零通知；铃声 + bellStyle 形成 B3 人机协议）。 |

## 8. 多模态主线：图片作业规程

主线即视觉模型，图片作业从"路由架构"简化为"纪律"。全部规程：

1. **图片直接进对话**：粘贴截图、或让主线用 Read 读工作区图片（JPEG/PNG/GIF/WebP）——两条路径都以 image 块发给 flash，无 400 风险（旗舰/旧架构的"图片必须是文件、粘贴即错"纪律在本分支**不适用**；粘贴是合法且推荐的快捷路径）。
2. **落盘仍是默认形态**（推荐）：截图保存到工作区（`docs/evidence/`、`charts/`）再让主线 Read——收益：① 文件是持久证据，可转录落盘、可复查、可入报告引用链（"图片路径 + 转录 + 时间"）；② 上下文生命周期可控（视觉密集任务在阶段边界 `/clear` 后靠文件再引导）；③ 并行审查时可分发给多个子代理。粘贴适用于"一次性快看"，落盘适用于"进入证据链"。
3. **大图先裁剪**：客户端发送前会对超大图片缩放重编码，服务端再按自身规则换算（Z.AI 未公布 flash 的图片 token 换算细则）。高分屏局部报错、密集小字、需精确读数的图表，先裁感兴趣区域（Python Pillow/ImageMagick）再读；下达时指出关注区域（"右下角弹窗"）。
4. **先转录、后判读**：让主线输出 ① 客观转录（逐字：报错、错误码、栈帧、路径行号、轴刻度、数值标签）→ ② 结构描述 → ③ 结论。看不清就明说「不可辨认」，区分「图中可见」与「由此推断」。
5. **视觉读数不进计算**：图表估读只用于形态判断与线索定位；进入计算与结论的数值必须回到数据接口/原文取证（11.2 铁律）。
6. **批量图片走并行子代理**：CI 失败截图墙、多页面 UI 走查——子代理继承主线视觉，按 7.10 的并发上调分批派发（每批数十张），汇总结论回主线。
7. **验证与回退**：部署后先做第 17 章第 8 条验证（粘贴 + Read 各一次）。若 Anthropic 端点 image 块环节报错（未文档化环节，5.3 节）：图片改走 Vision MCP（14 章 `zai-mcp-server` 的视觉工具）应急，并在任务边界决策是否切回 main 架构。

## 9. 有意不设置的参数及原因

| 参数 | 决定 | 原因 |
| --- | --- | --- |
| `fallbackModel` | 绝不设置 | 过载自动换模型 = 静默降级出活（违反 A6/B1）。策略：看门狗重试同一模型 + 第 13 章窗口策略。 |
| `CLAUDE_CODE_EXTRA_BODY`（采样参数） | 不设置 | flash 官方推荐 `temperature=1`、`top_p=0.95`——即其默认标定工况；注入无收益。数值确定性由"工具算数"保证（11.2）。 |
| `MAX_THINKING_TOKENS` | 不设置 | flash 思考不可关闭且深度由 `reasoning_effort` 控制（已锁 max）。 |
| `DISABLE_PROMPT_CACHING` 及 TTL 类 | 绝不设置 | 缓存无损；TTL 属 Anthropic 计费机制，Z.AI 隐式缓存无对应物。 |
| `CLAUDE_CODE_DISABLE_1M_CONTEXT` | 绝不设置 | 会使 `[1m]` 按 200K 处理。 |
| `ANTHROPIC_API_KEY` | 不设置 | 使用 `ANTHROPIC_AUTH_TOKEN`；残留必须删除。 |
| 子代理嵌套深度（`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`） | 保持默认 3 | 见 7.10：深度与并发不同维度，调大导致上下文膨胀不可汇聚。 |
| `ENABLE_TOOL_SEARCH` | 保持默认 | 需端点支持 `tool_reference`，Z.AI 未声明。 |
| `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` | 默认不设 | 仅当端点对 `anthropic-beta` 头报错时临时置 1。 |
| `DISABLE_INTERLEAVED_THINKING` | 不设置 | 工具间思考是 A3/B4 要求（flash 默认支持）。 |
| `DISABLE_AUTO_COMPACT` / `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | 不设置 | 800K 水位自动压缩是最后防线；百分比旋钮与绝对水位叠加会使触发点不可推算——单旋钮原则。 |
| `verbose` / `askUserQuestionTimeout` / `crossSessionInbound`（默认 hold）/ `keybindingFlavor` / `voice` / channels | 不设置/默认 | 显示层由 fullscreen 承担；自动继续与人工闸门冲突；hold 是防注入设计；键位个人偏好；语音/channels 需 claude.ai 账号。 |
| `feedbackDrafts` | 保持默认 | v2.1.247 SendFeedback 草稿——非必要流量已被 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` 整体关闭。 |
| `experimental.cacheTtl`（agent frontmatter） | 不设置 | v2.1.248 每代理缓存 TTL——Anthropic 计费机制，Z.AI 隐式缓存无对应物。 |
| `desktopSessionCleanupPeriodDays` | 不设置 | v2.1.248 Claude Desktop 会话清理豁免——Desktop 体系专属，网关模式无此会话。 |
| `CLAUDE_CODE_RESTRICTED=1`（`--restricted`） | **绝不使用** | v2.1.248 受限模式：移除命令执行工具、**拒绝 bypassPermissions、忽略用户级 settings**——与本配置正相反，属管理员锁定开关。 |
| `sandbox.*` | 不设置 | 仅支持 macOS/Linux/WSL2；Windows 原生 PowerShell 不支持。 |
| `fastMode` | 不设置 | Anthropic 原生 Opus 加速计费特性，网关无此通道。 |
| `CLAUDE_CODE_MAX_WEBSEARCH_USES` | 保持默认 | 内置 WebSearch 网关下本就不可用（7.8），无实际约束意义。 |
| `modelPicker` | 不设置 | 四别名位已钉死 flash，选单无备选。 |
| `CLAUDE_CODE_GOAL_CHECKIN_MINUTES` | 不设置 | 未采用 `/goal` 工作流。 |
| `CLAUDE_CODE_WORKFLOW_PREFIX_STAGGER_MS` | 保持默认 5000 | fan-out 缓存前缀错峰，Z.AI 隐式缓存下保留默认即免费收益。 |
| `apiKeyHelper` | 不设置 | 单账号场景直接用 `ANTHROPIC_AUTH_TOKEN`；flash 下触顶频率约 1/3，自动轮换的必要性进一步下降（第 13 章），保持简单。 |

---

# 第三部分：作业手册

## 10. 场景 ①：BMC 级代码体系的高强度并行开发

### 10.1 工作区形态

主仓启动 + `/add-dir` 挂载兄弟仓库（u-boot、kernel、webui……）；`CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` 保证各仓 CLAUDE.md 全载入。超大单树参考官方 monorepo 专文。

### 10.2 根 CLAUDE.md 模板（置于主仓根目录，按实际改写）

```markdown
# 工程语境
- 本工作区为 BMC 固件全栈：Yocto/bitbake 元层、u-boot、Linux 内核（I2C/IPMB/KCS/MCTP 驱动）、
  phosphor-* D-Bus 服务、bmcweb（Redfish）、webui-vue 前端。
- 目标机型/SoC：<填写>；交叉工具链：<填写>；构建入口：<bitbake 命令/脚本>。

# 硬性约束（违反即返工）
1. 协议字段、寄存器位、D-Bus 接口签名：必须先读到规范文本或现有代码定义再落笔，
   禁止凭记忆书写。引用时注明文件路径与行号。
2. 内存与实时性：守护进程热路径禁止动态分配与阻塞 I/O；新增依赖评估镜像体积。
3. 禁改区：vendor blob、签名/安全启动密钥与流程、许可证头。
4. 每次代码改动后依次执行：<格式化>、<静态检查>、<单元测试>；
   跨组件改动完成 <QEMU 冒烟>。任何一步失败不得宣布完成。
5. commit 边界：一个逻辑变更一个 commit；禁止顺手重构无关代码。

# 视觉证据规程（主线多模态）
- 报错截图、原理图、时序图、面板照片：可直接粘贴或落盘（docs/evidence/）后让我 Read；
  关键转录注明「图片路径 + 转录 + 获取时间」并落盘归档。
- 大图先裁剪关注区域再读；看不清的内容标注「不可辨认」，禁止脑补。
- 视觉估读不进计算；进入结论的数值回代码/数据接口取证。

# 长任务规程
- 阶段性结论（架构判断、影响面清单、风险点）写入 docs/worklog/<日期>-<主题>.md 后再继续。
- 小时级构建用后台方式运行。
- 上下文压缩时完整保留：硬性约束全文、当前阶段目标与未完成事项、
  已修改文件清单及验证命令、未通过的失败项与报错原文。

# 检索优先级
上游/开源参考：优先 zread 读 GitHub 仓库；网页文档用 web-reader 取全文。
```

### 10.3 证据落盘与上下文生命周期（通用规程）

证据的持久层在文件系统不在对话窗口：阶段结论先落盘 → 阶段边界 `/context` ≥60% 即收尾压缩（带聚焦指令）→ 任务切换 `/clear` + worklog 再引导 → 大规模检索交子代理（结论回主线）→ 部分压缩用 `/rewind`。视觉密集任务注意：图片 token 计入窗口，截图随证据一起落盘、会话勤清段（第 8 章第 2 条）。

### 10.4 高强度并行的正确形态

- **总量排队 ≠ 并发堆高**：spawn 超出 40 并发的部分自动排队；单会话内"总量"无上限（v2.1.224 起已移除总量上限），workflow 单 run 1000 代理。
- **审计/迁移用 workflow**：`ultracode` 关键词（交互输入）或 `claude --effort ultracode -p`（无人值守）触发；workflow 子代理强制 acceptEdits + 继承 20 条 allow（7.9）。
- **fork 用于带上下文的方案对比**；agent teams 用于一人主控多队友分模块。
- **并行正确性纪律**：多代理改同一文件集时用 worktree 隔离；汇总阶段显式要求"逐代理列出改动文件清单"防互相覆盖。
- 深度代码审查用 `/code-review high|xhigh`（后台 agent 运行不阻塞主线）。

## 11. 场景 ②：A 股例行分析（产能轨）

### 11.1 总原则

LLM 是编排器不是数据库，数字全部来自当轮工具调用。本场景主打**高频例行**——flash 的 3× 窗口容量使每日例行 + 周度专题可长期不间断运行（B5）；重大专题（对抗互验深核查）按第 2 章分工走 main。

### 11.2 数据铁律（写入 CLAUDE.md）

1. 零记忆数字：一切行情/财务数字来自当轮工具调用，标注「来源 + 获取时间」。
2. 计算全部落代码（pandas；脚本与中间数据落盘 data/、scripts/）。
3. 关键数字双源交叉；不一致披露差异与取舍。
4. 来源分级：交易所/法定披露 > 结构化接口（akshare 等）> 财经媒体；低级来源只佐证。
5. 有损工具不入账：WebFetch 仅泛读；关键取证用 web-reader 全文或 curl/requests 原始页面。
6. 搜索走 web-search-prime + web-reader（内置 WebSearch 网关下不可用）。
7. **图表证据主线直读**：K 线图、研报截图直接发给主线（粘贴/Read），按第 8 章规程转录；估读不进计算。

### 11.3 A 股 CLAUDE.md 模板（置于分析工作区根目录）

```markdown
# 角色与目标
你是 A 股市场分析工程师：取数、验证、计算、组织多空论证，产出可审计的分析报告。

# 数据铁律（不可违反）
1. 任何数字来自本轮工具调用，标注来源与获取时间；禁止凭记忆给数。
2. 一切计算写 Python 执行（pandas）；脚本与中间数据落盘 data/ 与 scripts/。
3. 关键数字双源交叉验证；不一致必须披露。
4. 数据不可得就明说「取不到」，禁止估计冒充实际。

# 口径声明（每份报告开头必须给出）
- 数据截止时间（Asia/Shanghai）；行情快照 vs 收盘数据。
- 复权方式；单位统一（元/万元/亿元）；报告期与公告日分开标注。
- 指数/板块口径（代码与编制方）。

# 图表证据规程
- K 线/研报/数据平台截图：落盘 charts/ 后让我 Read，或直接粘贴；
  先锁口径（轴含义、时间范围、复权、单位）再读数；估读带精度区间。
- 精确数值回数据接口取证；视觉读数只做形态判断。

# 交易规则常识（计算与回测内建）
- T+1；涨跌停：主板 ±10%、ST ±5%、创业板/科创板 ±20%、北交所 ±30%。
- 回看历史用时点数据（point-in-time），防幸存者偏差。

# 输出规范
- 报告落盘 reports/<日期>-<主题>.md；附来源清单表（数值|来源|时间|校验源）。
- 区分「事实（带来源）」「推断（带逻辑链）」「观点（带置信度）」。
- 本工作区只做研究，不接实盘下单接口。

# 上下文压缩保留项
- 口径声明全文；来源清单表；未完成核查项；结论的可证伪条件。
```

### 11.4 无人值守双轨

```powershell
# 轨道一：每日例行（结构稳定、日间可比）
claude -p "执行每日例行分析：按 CLAUDE.md 铁律更新自选池数据、运行 scripts/daily.py、
生成 reports/$(Get-Date -Format yyyy-MM-dd)-daily.md，全部数字附来源清单"

# 轨道二：周度专题（多路并行核查）
claude --effort ultracode -p "对 <标的/行业> 做多空核查：多角度分头取证、交叉互验后汇总裁决；
检索用 web-search-prime、读页用 web-reader；产出 reports/<日期>-weekly.md，数字附来源清单"
```

要点：`ultracode` 关键词仅对人工输入生效（`-p` 中必须用 `--effort ultracode` 旗标）；`CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0` 已内置（headless 无限等待）；产物落盘 = 审计底稿；需要中途跟进的改 `claude --bg --effort ultracode "..."`（supervisor 托管，关终端不中断）。

### 11.5 实盘边界

实盘下单脚本独立仓库 + 该仓库 `.claude/settings.local.json` 窄 deny（`Bash(python live_trade.py*)` 等）；deny 全模式生效，是唯一硬闸。

## 12. 场景 ③：视觉密集工作流

### 12.1 UI 迭代闭环（官方"视觉融入 coding 循环"的落地）

单会话内的标准循环：

```text
改码 → 运行/构建 → 截图（保存 docs/evidence/ui-<时间戳>.png）
→ "Read docs/evidence/ui-<时间戳>.png，对照 <设计稿/上一版> 列出差异"
→ 按差异改码 → 循环，直至逐项确认
```

纪律：每轮截图**落盘并带时间戳命名**（版本可追溯、压缩/清空后可回看）；比对输出要求"逐区块差异清单 + 位置标注"；webui 类目标用浏览器截图工具/Playwright 脚本化产出。设计稿与实况两张图可同轮发出（多图单轮）。

### 12.2 Debug 截图诊断

报错弹窗/崩溃转储/串口日志照片：直接粘贴或落盘后 Read；要求完整提取报错文本、错误码、栈帧、可见环境线索（终端标题、路径、版本、时间戳）；截断处明确标注。BMC 现场（串口照片、面板指示灯）同理。

### 12.3 批量截图并行审查

CI 失败截图墙、多页面走查、多机型面板照片：

```text
"用 workflow 并行审查 docs/evidence/ci-fail-<日期>/ 下全部截图：每代理认领 <10 张，
逐张提取报错与栈帧、归类根因（编译/链接/测试/环境），汇总去重后的根因清单与出现频次"
```

子代理继承主线视觉；40 并发（7.10）使百张级截图墙一轮跑完。汇总阶段要求"每条根因附截图文件名"保持可追溯。

### 12.4 图表/K 线/研报读数

按第 8 章规程：先锁口径（轴、单位、时间、复权），再转录再判读；读数带估读区间；精确值回数据接口。研报扫描件的文字提取同样走主线直读，密集小字先裁剪放大。

---

# 第四部分：运维

## 13. 5 小时窗口与配额策略

**容量数学**：MAX 档 5h 窗口约 1600 旗舰 prompts（官方套餐口径）；flash 配额消耗约 1/3 → 等效约 4800 prompts/5h；周配额（约 8000 旗舰 prompts）同理 3×。推算口径，实际以 Z.AI 控制台显示为准。

**日常策略**：

1. **例行任务排满不心虚**：每日例行 + 周度专题 + 白天交互开发同窗口并存，是 flash 产能定位的设计工况；触顶概率相对旗舰降为约 1/3。
2. **触顶处置**（按序）：等窗口重置（5h 滚动）→ 任务切换到低峰时段 → 多账号切换（修改 `ANTHROPIC_AUTH_TOKEN`，`env` 块热加载通常无需重启；或 `CLAUDE_CONFIG_DIR` 整目录切换，新目录需重做 14 章 MCP 注册）。切换账号 = 缓存主体切换，首轮冷启动，尽量在任务边界执行。
3. **观测**：Z.AI 控制台用量页；重度并行日留意 429 频率——密集则把并发回落（7.10 处置）。
4. Z.AI 政策禁止账号共享/多用户，同一使用者多订阅轮换不属此列，需关注政策更新。

## 14. 专属 MCP 部署（Coding Plan 四件套）

MAX 档配额：Web Search + Web Reader + Zread 共享每月 4000 次；Vision 走套餐 5h prompt 资源池。配额用尽仅暂停 MCP 不扣余额。

部署（用户作用域写入 `%USERPROFILE%\.claude.json`）：

```powershell
# Vision（本地 stdio，Node ≥ 22）——本分支定位：视频分析 + 主线图片的回退通道
claude mcp add -s user zai-mcp-server --env Z_AI_API_KEY=your_api_key --env Z_AI_MODE=ZAI -- npx -y "@z_ai/mcp-server@latest"
# Web Search（远程 HTTP）
claude mcp add -s user -t http web-search-prime https://api.z.ai/api/mcp/web_search_prime/mcp --header "Authorization: Bearer your_api_key"
# Web Reader（远程 HTTP）
claude mcp add -s user -t http web-reader https://api.z.ai/api/mcp/web_reader/mcp --header "Authorization: Bearer your_api_key"
# Zread（远程 HTTP，GitHub 仓库理解）
claude mcp add -s user -t http zread https://api.z.ai/api/mcp/zread/mcp --header "Authorization: Bearer your_api_key"
```

定位说明：主线原生多模态已覆盖**静态图片**的全部场景（第 8 章）；Vision MCP（后端 GLM-4.6V）保留两个角色——① **视频分析**（`video_analysis`，≤8MB MP4/MOV/M4V：Read 路径只发图片，视频仍需它）；② **回退通道**（Anthropic 端点 image 块异常时的应急视觉来源，17/18 章）。Web Search/Reader/Zread：A 股时效主入口、取证级读页、上游仓库理解。

验证：`claude mcp list` 四个 connected；服务器名与 allow 规则一致（`zai-mcp-server`/`web-search-prime`/`web-reader`/`zread`）。

- 来源：[Z.AI – Coding Plan Overview](https://docs.z.ai/devpack/overview)、[Z.AI – Vision MCP Server](https://docs.z.ai/devpack/mcp/vision-mcp-server)、[Claude Code – MCP](https://code.claude.com/docs/en/mcp)

## 15. 升级 SOP

自动更新已被 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` 关闭，升级完全主动执行：

1. 确认无任务运行（升级 = 系统提示变化 = 行为漂移 + 缓存冷启动，只在任务间隙）。
2. 连接 VPN → `claude --version` 记录版本 → 升级（原生 `claude update` / WinGet / npm）→ `claude doctor` 验证。
3. 断开 VPN 正常使用（模型流量仅走 `api.z.ai`）。
4. 升级后从新会话开始新任务；避免立即 `--resume` 长会话（无缓存重放 + 行为漂移）。
5. 每次升级后按第 17 章清单回归（重点第 3/8/9 条），并对照官方 CHANGELOG 核对本手册第 9/20 章。

## 16. 一致性管理：行为漂移源清单

任务进行中一律避免，移至任务边界：

| 漂移源 | 后果 | 对策 |
| --- | --- | --- |
| `/model` 切换模型 | 不同模型 = 不同回答者 | 全 flash 单模型，选单无备选 |
| `/effort` 切换档位 | 推理深度改变 | 环境变量锁定 xhigh（=max），`/effort` 失效 |
| 升级 Claude Code | 系统提示/工具定义变化 | 第 15 章 SOP |
| MCP 中途连接/断开 | 工具集合变化 | 四件套一次配齐不再变动 |
| 裸工具名 deny | 工具集合变化 | deny 保持为空 |
| `/compact` / 水位调整 | 对话史被摘要替换 / 触发点改变 | 阶段边界执行；水位由环境变量锁定 |
| 中途修改 CLAUDE.md | 本会话不生效 | 修改后重启会话再开工 |
| main ↔ flash 分支切换 | 模型与架构整体改变 | 最高级别漂移：只在任务边界，且切换后新会话 |

无漂移风险：编辑仓库文件、Shift+Tab、技能/命令、`/recap`、`/rewind`、派生子代理。观测：`/status`（模型与设置来源）、`/context`（窗口与水位）、`/effort`（接管状态）、`/tasks`（子代理实际模型）。

## 17. 部署后验证清单

| # | 动作 | 期望结果 |
| --- | --- | --- |
| 1 | `claude --version` | ≥ v2.1.233（第 20 章；低于 minimumVersion 拒绝启动） |
| 2 | 启动 `claude` | 无认证报错；`⏵⏵ bypass permissions on` 徽标 |
| 3 | `/status` | Model 为 `glm-5.3-flash[1m]`（显示名 **GLM-5.3-Flash (1M)**）；Setting sources 含 User settings |
| 4 | `/model` | 各别名位均显示 GLM-5.3-Flash；无旗舰/旧模型备选 |
| 5 | `/effort` | 档位被环境变量接管（xhigh） |
| 6 | `/context` | 窗口按 1M 计；`/autocompact` 报告水位 800000 被环境变量接管 |
| 7 | 复杂提问 | 思考可见（`Ctrl+O`），流式稳定 |
| 8 | **粘贴一张截图进主会话 + 让主线 Read 另一张工作区图片** | **两者均正常识别与描述**（主线原生多模态 + Anthropic 端点 image 块验证）。若报错：按第 18 章"主线图片报错"行处置 |
| 9 | 批量并行：`ultracode: 并行审查 <目录> 下截图/用法` | workflow 触发，并行代理数可观（并发 40），`/workflows` 可见；`/tasks` 显示子代理模型为 glm-5.3-flash |
| 10 | `claude mcp list` | 四个 MCP connected |
| 11 | "搜索今天沪深两市成交额并给来源" | 走 web-search-prime + web-reader，数字带来源与时间 |
| 12 | Shift+Tab | manual → acceptEdits → plan → bypass 循环 |
| 13 | 断开 Anthropic 访问 | 无升级/遥测报错；WebFetch 可用 |
| 14 | `/tui` | Current renderer: fullscreen |
| 15 | 长任务切走窗口 | 完成时终端铃声 |
| 16 | 多步清单任务 | TaskCreate/TaskUpdate 正常调用 |
| 17 | 部署位检查 | `%USERPROFILE%\.claude\agents\` **无 vision.md 残留** |

## 18. 故障排查速查表

| 症状 | 原因 | 处置 |
| --- | --- | --- |
| `1113 Insufficient Balance` / 扣余额 | Base URL 错误（走了普通 API 端点）或模型名不在允许列表 | 核对 `https://api.z.ai/api/anthropic` 与 `glm-5.3-flash[1m]`；[Z.AI FAQ](https://docs.z.ai/devpack/faq) |
| `glm-5.3-flash[1m]` 模型不存在 | CLI 版本过旧（后缀解析依赖新版） | VPN 下升级；[Z.AI – 切换模型](https://docs.z.ai/devpack/latest-model) |
| **主线图片报错（400/415 类）** | Anthropic 端点 image 内容块环节异常（官方仅文档化 OpenAI 格式 image_url，见 5.3） | 应急：图片走 Vision MCP（14 章）；任务边界决策切回 main 架构；向 Z.AI 反馈确认端点图片支持状态后更新第 8 章口径 |
| 图片被读取但细节丢失 | 客户端压缩 + 服务端换算两级吃细节 | 第 8 章第 3 条：先裁剪感兴趣区域；下达时指明关注区域 |
| **429 密集出现** | 并发上调（40/20）超出端点当前动态限额 | `CLAUDE_CODE_RETRY_WATCHDOG` 自动退避吸收；持续密集则把两键回落 20/10（7.10 知情取舍），勿关看门狗 |
| 子代理 spawn 被拒 | CLI < v2.1.224（旧 200 总量上限） | 升级；现行约束为并发 40/深度 3，超出排队 |
| 任务清单工具不可用 | 新版对较新模型默认移除 | `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` 生效确认 |
| `ultracode` 不触发 workflow | 锁定档非 xhigh / 关键词在 `-p` 中 | 确认 `CLAUDE_CODE_EFFORT_LEVEL=xhigh`；无人值守用 `--effort ultracode` |
| workflow 代理数十几个封顶 | `workflowSizeGuideline` 被 medium 引导 | 确认 `unrestricted` 未被项目级覆盖 |
| 无人值守 10 分钟被终止 | headless 默认后台等待上限 | `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0` 已内置，核对来源 |
| 会话逼近 1M 卡死（压缩双失败） | 水位曾设满格/被覆盖 | 本配置 800K 水位根治；存量会话 `/rewind` 部分摘要 → 导出重开 |
| 压缩后关键数字丢失 | 摘要未保留且未落盘 | 10.3 规程：先落盘再压缩；数字重取不凭摘要复述 |
| WebFetch 全部失败 | 预检未跳过 | `skipWebFetchPreflight: true` |
| 内置 WebSearch 报错 | Anthropic 服务端工具，网关不可用 | 用 web-search-prime（预期行为） |
| 修改 settings 不生效 | 语法错误/位置错误/旧窗口 | 重开全部窗口；`/status` 查来源；`claude doctor` |
| Vision MCP 秒断 | Node<22 / npx 缓存旧版 / Key 未配置 | `node -v` ≥22；`@latest`；裸跑测试 |
| 三远程 MCP 集体失效 | 月配额 4000 次用尽或 Key 失效 | 控制台查用量；等待下月或切账号 |
| 5h 窗口触顶 | 高强度使用（概率约为旗舰 1/3） | 第 13 章处置序列 |
| 全屏残影/错位 | ConPTY 增量重绘缺陷 | `CLAUDE_CODE_ALT_SCREEN_FULL_REPAINT=1` 确认；叠加 `CLAUDE_CODE_DISABLE_VIRTUAL_SCROLL=1`；临时 `/tui default` |
| 后台子代理误标 failed | 长命令无进度事件被判失速 | 已放宽 1h；超长构建用后台命令 |

---

# 第五部分：附录

## 19. 基准数据备查

**GLM-5.3-Flash 官方图表**（docs.bigmodel.cn，DeepSWE/TB/ALE/AutomationBench/HLE/GDPval 列于第 1 章总表）：TB2.1 84.3 / DeepSWE v1.1 63.4 / ALE 26.3 / AutomationBench 48.8 / HLE w/Tools 55.3 / GDPval-AA v2 1773；Z.ai Code Bench Max effort 29.0（各 effort 档全面超 GLM-5.2）；AA 智能指数 57。

**GLM-5.3 旗舰对照**（z.ai/blog/glm-5.3，2026-08-14）：TB2.1 88.2 / TB3.0 28.3 / DeepSWE v1.1 66.9 / FrontierSWE 78.1 / SWE-Marathon v1.1 42.5 / PostTrainBench 39.8 / ALE 28.5 / CyberGym 84.5 / Toolathlon Verified 73.0 / NL2Repo 58.0 / ZCB Max 34.5%@75K。

**竞品同表对照**（官方表内数字）：Opus 4.8——TB2.1 85.0 / TB3.0 21.1 / DeepSWE 58.0 / FrontierSWE 66.5 / SWE-Marathon 48.8 / ALE 25.7–27.0 / CyberGym 78.1 / AA 57；DeepSeek-V4-Pro-0813——TB2.1 87.9 / DeepSWE 62.7 / NL2Repo 61.1 / ALE 25.7 / CyberGym 83.3 / AA ≈53；Gemini 3.7 Flash——TB2.1 85.8 / DeepSWE 65.3 / ALE 28.0；GPT-5.6 Sol——TB2.1 88.8 / TB3.0 34.6 / DeepSWE 72.7 / ALE 28.6。

**规格与定价**：1M 上下文；最大输出与 GLM-5.3 一致（128K）；`reasoning_effort` low/high/max 默认 max；思考不可关闭；API 价格输入 $0.075 / 输出 $0.25（促销至 2026-09-09，原价 $0.15/$0.50；旗舰 $1.4/$4.4）；缓存输入 $0.015。Coding Plan 配额消耗约为旗舰 1/3（官方"3 倍额度"定位）。

**口径总声明**：以上全部为厂商自报（自跑 harness）；tbench.ai 官方验证榜无 5.3 系条目；SWE-bench Verified / LiveCodeBench / Aider Polyglot 无 5.3 世代官方数据。跨厂商横比仅作方向参考。

## 20. 版本门槛备查表

| 变量（本配置值） | 最低版本 | 旧版行为 |
| --- | --- | --- |
| `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=40` | v2.1.217 | 无此变量（更旧版本为单会话 200 总量上限语义，v2.1.224 起移除） |
| `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` | v2.1.233 | 无此变量；任务清单工具缺失 |
| `workflowSizeGuideline=unrestricted`（设置键） | v2.1.219 | 旧版忽略该键；2.1.219 起默认 medium |
| `CLAUDE_CODE_FORK_SUBAGENT=1` 在 `-p` 下生效 | v2.1.232 | 旧版 `-p` 下需显式置 1，语义一致 |
| `CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS=0` | v2.1.212 | 静默回退 2 分钟自动转后台 |
| `CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT=600000` | v2.1.187 | 走传输层默认 |
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS` 对自定义模型名直接生效 | v2.1.193 | 需配合其他条件 |
| `CLAUDE_CODE_RETRY_WATCHDOG=1`（含计费类 429 立即失败语义） | v2.1.186（语义细化 v2.1.239） | 无看门狗，按默认重试 |
| `--effort ultracode` 启动参数 | v2.1.203 | 报 Unknown value |
| 子代理 frontmatter `model` 完整 ID 语义（备用） | v2.1.196+ | 更旧版本 inherit 语义不同 |

`minimumVersion: "2.1.233"` 把门槛固化为启动检查（切换发布通道降级直接拒绝运行）。使用者当前环境 v2.1.250；v2.1.247–250 区间本配置零改动（新增键取舍见第 9 章；2.1.249 未发布）。

## 21. 参考链接汇总

**Claude Code 官方文档**：[总览](https://code.claude.com/docs/en/overview) · [Settings](https://code.claude.com/docs/en/settings) · [env-vars](https://code.claude.com/docs/en/env-vars) · [模型配置](https://code.claude.com/docs/en/model-config) · [权限](https://code.claude.com/docs/en/permissions) · [权限模式](https://code.claude.com/docs/en/permission-modes) · [工具参考](https://code.claude.com/docs/en/tools-reference) · [提示缓存](https://code.claude.com/docs/en/prompt-caching) · [MCP](https://code.claude.com/docs/en/mcp) · [Workflows](https://code.claude.com/docs/en/workflows) · [Agent view](https://code.claude.com/docs/en/agent-view) · [Fullscreen](https://code.claude.com/docs/en/fullscreen) · [终端配置](https://code.claude.com/docs/en/terminal-config) · [子代理](https://code.claude.com/docs/en/sub-agents) · [上下文窗口](https://code.claude.com/docs/en/context-window) · [最佳实践](https://code.claude.com/docs/en/best-practices) · [大代码库](https://code.claude.com/docs/en/large-codebases) · [记忆](https://code.claude.com/docs/en/memory) · [Fast mode](https://code.claude.com/docs/en/fast-mode) · [Statusline](https://code.claude.com/docs/en/statusline) · [CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)

**Z.AI 官方文档**：[文档首页](https://docs.z.ai) · [GLM-5.3（旗舰，text-only 声明）](https://docs.z.ai/guides/llm/glm-5.3) · [GLM-5.3-Flash（原生多模态与推荐参数）](https://docs.z.ai/guides/vlm/glm-5.3-flash) · [定价](https://docs.z.ai/guides/overview/pricing) · [Coding Plan 总览](https://docs.z.ai/devpack/overview) · [快速开始](https://docs.z.ai/devpack/quick-start) · [Claude Code 接入](https://docs.z.ai/devpack/tool/claude) · [切换模型](https://docs.z.ai/devpack/latest-model) · [FAQ](https://docs.z.ai/devpack/faq) · [使用政策](https://docs.z.ai/devpack/usage-policy) · [Vision MCP](https://docs.z.ai/devpack/mcp/vision-mcp-server) · [Web Search MCP](https://docs.z.ai/devpack/mcp/search-mcp-server) · [Web Reader MCP](https://docs.z.ai/devpack/mcp/reader-mcp-server) · [Zread MCP](https://docs.z.ai/devpack/mcp/zread-mcp-server)

**官方发布与基准**：[Z.ai – GLM-5.3 发布博客（旗舰基准全表）](https://z.ai/blog/glm-5.3) · [智谱开放平台 – GLM-5.3-Flash（Flash 基准与 AA 指数）](https://docs.bigmodel.cn/cn/guide/models/vlm/glm-5.3-flash) · [智谱开放平台 – GLM-5.3](https://docs.bigmodel.cn/cn/guide/models/text/glm-5.3) · [tbench.ai 验证榜（口径核对用）](https://www.tbench.ai/leaderboard/terminal-bench/2.1) · [Artificial Analysis](https://artificialanalysis.ai)

**长上下文质量研究（7.4 定调依据）**：[Anthropic – Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) · [Chroma – Context Rot](https://research.trychroma.com/context-rot) · [NoLiMa（ICML 2025）](https://arxiv.org/abs/2502.05167) · [RULER（COLM 2024）](https://arxiv.org/abs/2404.06654)
