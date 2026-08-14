# glm-settings

GLM Coding Plan MAX × Claude Code（Windows CLI）——面向**正确性、完备性、可靠性**的极致化配置。成本与速度不纳入决策考量；全链路（含后台辅助任务与全部子代理）仅运行 **GLM-5.2**，无备选、无回退。

| 文件 | 说明 |
| --- | --- |
| [`settings.json`](./settings.json) | 部署至 `%USERPROFILE%\.claude\settings.json`，仅需将 `ANTHROPIC_AUTH_TOKEN` 替换为实际的 Z.AI API Key（已通过官方 JSON Schema 严格校验） |
| [`GUIDE.md`](./GUIDE.md) | 配置与作业手册：两大场景（BMC 级超大代码体系开发、A 股持续深度行情分析）的需求规格与追溯矩阵；参数逐项详解（附权威来源链接）；专属 MCP 部署；无人值守双轨制；多账号轮换；升级 SOP；漂移源清单；两份 CLAUDE.md 模板 |

核心设定：effort 锁定 `xhigh`（经 Z.AI 映射即 `reasoning_effort=max`，且保留 ultracode 动态工作流编排通道）、1M 上下文全程可用、工具输出与 MCP 执行超时按官方上限放宽不截断、三层流式看门狗 + 无人值守重试 + headless 后台无限等待、默认 `bypassPermissions` 全自动（allow 清单同时是 workflow 子代理的免批通行证）。
