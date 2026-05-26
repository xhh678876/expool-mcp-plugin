---
description: 在经验池里做语义检索（覆盖个人池和社区池）。任务开工前先跑一遍。
argument-hint: "\"<query text>\" [--top-k N] [--scope auto|personal|community]"
allowed-tools: [mcp__expool__exp_search]
---

## 输出规范（全 /expool:* 命令统一）

- **回复语言：全中文。** 表头、字段名以外的解释、提示都用中文。
- **字段释义：** 服务端字段第一次出现时附一句中文释义。常见字段速查：
  - `auto_approved` 自动审核通过 · `pending` 待人工审核 · `revoked` 已撤回
  - `skipped` 本轮看过但已存档，不重复推送
  - `available_now` 本地可见的 session 总数
  - `redactions` 上传前 layer-1 自动脱敏的次数（按字段统计）
  - `community_unlocked` 是否解锁向社区池发布
  - `acl=private/public/team:<name>` 仅自己 / 全社区 / 指定团队
- **不要直接贴原始 JSON**；用紧凑表格或要点列表呈现。

---

## 工作流

在经验池里做语义检索，找用户当前任务的历史"做过没"。

参数解析（`$ARGUMENTS`）：
- 引号包裹的文本 → 作为查询字符串 `q`
- `--top-k <N>` → 覆盖 `top_k`（默认 5）
- `--scope <scope>` → 覆盖 `scope`（默认 `auto`；可选 `personal` 仅个人池 / `community` 仅社区池）
- `--task-type <type>` → 可选筛选某种 task_type
- 若 `$ARGUMENTS` 是不带引号的自由文本，整串作为 `q`

调用 `mcp__expool__exp_search`，传以上参数。

## 渲染要求

**紧凑展示**，不要贴原始 JSON。每条结果用一个小块：

```
[<id8>]  intent: <意图，截断到 120 字符>
         task=<task_type>  sim=<相似度，保留 3 位小数>  scope=<personal|community>
         outcome: <一行结果摘要>
```

若 top hit 相似度高、看起来直接可复用，末尾给一句提示：

> 💡 最佳命中 `<id8>` 看起来可复用 —— 回复"用它"或跑 `/expool:get <id8>` 看完整卡片。
