---
description: 使用平台侧 RAG 池检索经验片段；需要浏览完整卡片时再用 /expool:get。
argument-hint: "\"<query text>\" [--top-k N] [--scope auto|personal|community|project:<slug>]"
allowed-tools: [mcp__expool__exp_rag_context, mcp__expool__exp_search]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

## 工作流

在经验池里做语义检索，找用户当前任务可复用的历史经验片段。默认走平台侧 RAG chunk 检索；只有网关或插件版本过旧、不支持 `exp_rag_context` 时，才 fallback 到卡片级 `exp_search`。

参数解析（`$ARGUMENTS`）：
- 引号包裹的文本 → 作为查询字符串 `q`
- `--top-k <N>` → 覆盖 `top_k`（默认 5）
- `--scope <scope>` → 覆盖 `scope`（默认 `personal`；可选 `personal` 仅个人池 / `community` 仅社区池 / `project:<slug>` 项目池 / `auto` 自动）
- `--task-type <type>` → 可选筛选某种 task_type
- 若 `$ARGUMENTS` 是不带引号的自由文本，整串作为 `q`

优先调用 `mcp__expool__exp_rag_context`，传以上参数：

- `q` = 查询字符串
- `top_k` = 默认 5
- `scope` = 默认 `personal`
- `task_type` = 可选

如果当前环境没有 `exp_rag_context` 工具，再调用 `mcp__expool__exp_search` 兼容旧插件。

## 渲染要求

**紧凑展示**，不要贴原始 JSON。每条结果用一个小块：

```
[<id8>]  score=<相关度，保留 2 位>  chunk=<片段类型>  scope=<personal|community|project>
         <片段摘要，截断到 160 字符>
```

若 top hit 看起来直接可复用，末尾给一句提示：

> 💡 最佳命中 `<id8>` 看起来可复用 —— 回复"用它"或跑 `/expool:get <id8>` 看完整卡片。
