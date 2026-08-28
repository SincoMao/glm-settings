# glm-settings

GLM Coding Plan MAX × Claude Code（Windows CLI）——面向**正确性、完备性、可靠性**的极致化配置。成本与速度不纳入决策考量；模型策略为**主线单旗舰 + 多模态专线**：一切文本推理（含后台辅助任务与全部常规子代理）仅运行 **GLM-5.3**，无备选、无回退；图片、视频、文档文件三类非文本证据为 **GLM-5.3-Flash**（GLM-5 系列首个原生多模态模型，旗舰为纯文本）的独占承载，经专用 vision 子代理最大化利用（图片直读、视频抽帧、PDF 分页），与主线物理隔离；Vision MCP 仅作 flash 通道异常时的最后兜底。`glm-5.3-flash` 分支提供全 Flash 版配置（主线即多模态模型、配额消耗约为旗舰 1/3），适用边界见该分支的 GUIDE。

| 文件 | 说明 |
| --- | --- |
| [`settings.json`](./settings.json) | 部署至 `%USERPROFILE%\.claude\settings.json`，仅需将 `ANTHROPIC_AUTH_TOKEN` 替换为实际的 Z.AI API Key（已通过官方 JSON Schema 严格校验） |
| [`agents/vision.md`](./agents/vision.md) | 部署至 `%USERPROFILE%\.claude\agents\vision.md`——vision 子代理，多模态链路唯一主通道（截图诊断、录屏/视频抽帧取证、PDF 规范/研报分页阅读、图纸理解、K 线/图表读数），frontmatter 直指 `glm-5.3-flash` |
| [`GUIDE.md`](./GUIDE.md) | 配置与作业手册：三类需求（BMC 级超大代码体系开发、A 股持续深度行情分析、多模态证据链）的需求规格与追溯矩阵；参数逐项详解（附权威来源链接）；多模态子代理路由架构与作业手册（图片直读/视频抽帧/PDF 分页）；1M 窗口与压缩水位的机制定调（7.4.0）；上下文生命周期规程（9.4）；专属 MCP 部署；无人值守双轨制；多账号轮换；升级 SOP；漂移源清单；两份 CLAUDE.md 模板 |
| [`d-glm.bat`](./d-glm.bat) | **一键部署入口**：终端输入 `d-glm`（需本目录在 PATH）或到本目录双击运行，自动从 `GLM_API_KEY` 环境变量回填密钥并部署整套配置，详见下文「一键部署」 |
| [`deploy.ps1`](./deploy.ps1) | 部署逻辑本体（`d-glm.bat` 仅是薄封装；也可带参数直接运行，支持 `-KeyEnvName` / `-ProfileLabel` / `-AgentAction deploy|remove|none`） |

核心设定：effort 锁定 `xhigh`（经 Z.AI 映射即 `reasoning_effort=max`，且保留 ultracode 动态工作流编排通道，`workflowSizeGuideline=unrestricted` 对冲默认 `medium` 的 <15 代理规模引导）、1M 窗口 + 800K 压缩水位（压缩请求自身永不超窗，根治"逼近 1M 后手动/自动压缩双失败、会话死锁"；机制与权威依据见 GUIDE 7.4.0）、多模态经 vision 子代理路由（不占模型别名位、**不设 `CLAUDE_CODE_SUBAGENT_MODEL`** 以保 frontmatter 路由生效——主线粘贴图片会报错，图片/视频/PDF 一律落盘后点名 `@vision`，视频自动抽帧、PDF 自动分页；Vision MCP 仅作 flash 通道异常时的最后兜底）、工具输出与 MCP 执行超时按官方上限放宽不截断、三层流式看门狗 + 无人值守重试 + headless 后台无限等待、默认 `bypassPermissions` 全自动（20 条 allow 清单同时是 workflow 子代理的免批通行证）、fullscreen 渲染（内存恒定 + 压缩后全量回滚）+ 终端铃声完成通知（无人值守闭环）、`minimumVersion=2.1.233` 将版本门槛固化为启动检查。

## 一键部署（d-glm）

终端输入 `d-glm`（需本目录在 PATH）或双击 `d-glm.bat`，一条命令完成"回填密钥 + 部署 settings.json + 部署 vision 子代理 + 备份原配置"，无需手改文件、无需粘贴密钥。

一次性准备（设完永久生效；也可在「编辑账户的环境变量」界面手动添加）：

```powershell
setx GLM_API_KEY "sk-你的 Z.AI API Key"

# 将本仓库目录加入用户 PATH（按实际 clone 位置调整，不加 PATH 双击 .bat 亦可）
[Environment]::SetEnvironmentVariable('Path',
  [Environment]::GetEnvironmentVariable('Path','User') + ';D:\Source\glm-settings',
  'User')
```

日常部署：任意终端输入 `d-glm` 回车即可（PATH 变更需新开终端生效）。`deploy.ps1` 自动完成：

1. 读取 `GLM_API_KEY`（当前进程 → 用户级注册表，`setx` 设完无需重开终端）；
2. 回填 `ANTHROPIC_AUTH_TOKEN` 占位符，JSON 校验后以 UTF-8 无 BOM 写出，覆盖前自动将现有配置备份为 `.bak-<时间戳>`；
3. 部署 vision 子代理 `agents\vision.md` → `%USERPROFILE%\.claude\agents\vision.md`；
4. 打印端点 / 模型 / 密钥掩码摘要。

部署目标为 `%USERPROFILE%\.claude\settings.json`。已运行的会话不热加载 settings.json，部署后请新开 Claude Code 会话。
