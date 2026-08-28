# glm-settings（`glm-5.3-flash` 产能型专项分支）

GLM Coding Plan MAX × Claude Code（Windows CLI）——**产能型专项配置**：主线、后台辅助与全部子代理一律运行 **GLM-5.3-Flash**（GLM-5 系列首个原生多模态模型），主线直接接收图片输入，无视觉路由结构。与 main（旗舰版）分工：main 面向"单任务最深推理"，本分支面向"高强度并行 + 视觉密集 + 长时间高频使用"。

**四大支柱**（依据与口径详见 GUIDE 第 1–2 章）：

1. **次旗舰代码能力**——DeepSWE v1.1 63.4 反超 Opus 4.8（58.0）、AA 智能指数 57 与其持平（官方自报口径）
2. **原生多模态**——报错截图 / UI 走查 / K 线研报主线直读，视觉融入编码循环（改码→截图→比对→再改）
3. **配额吞吐**——Coding Plan 配额消耗约为旗舰 1/3：5h 窗口等效 ~4800 prompts（推算口径），触顶中断频率降为 1/3；配套子代理并发知情上调至 40、工具并发 20（各为默认值的 2×），429 由看门狗退避吸收、密集即回落
4. **API 价格**——按量场景的并行规模上限抬高一个量级（约为旗舰 1/10，限时促销约 1/18–1/20）

**知情边界**：极限长时程基准（TB3.0 / FrontierSWE / SWE-Marathon）flash 未公布成绩——架构级攻坚与马拉松任务请用 main；全部基准为厂商自报，tbench.ai 验证榜尚无 5.3 系条目。

| 文件 | 说明 |
| --- | --- |
| [`settings.json`](./settings.json) | 部署至 `%USERPROFILE%\.claude\settings.json`，替换 `ANTHROPIC_AUTH_TOKEN` 为实际 Z.AI API Key；三别名位 `glm-5.3-flash[1m]` + Haiku 位裸名 `glm-5.3-flash`，含 flash 专项并发调优（已通过官方 JSON Schema 校验） |
| [`GUIDE.md`](./GUIDE.md) | 产能型专项手册：四大支柱选型论证与口径声明；与 main 的分工矩阵；三场景（高强度并行开发 / A 股例行产能轨 / 视觉密集工作流）；多模态主线图片作业规程；并发上调的完整论证与回落预案；5h 窗口容量数学；无人值守双轨；MCP（Vision MCP 定位为视频 + 回退）；验证清单 / 故障表 / 基准备查 |

部署三步：settings.json 就位 → **删除** `~\.claude\agents\vision.md`（本架构无视觉子代理，残留即错误路由）→ 重启后按 GUIDE 第 17 章验证（重点第 3 条显示名、**第 8 条主线吃图**——Anthropic 端点 image 块为唯一待实测环节，回退 Vision MCP）。
