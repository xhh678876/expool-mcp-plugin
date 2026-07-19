---
description: 列出当前账号 private 库里的经验。
argument-hint: "[--limit N]"
allowed-tools: [mcp__expool__exp_list]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

## 工作流

列出当前账号个人池里的所有经验条目。

1. 解析 `$ARGUMENTS`：识别 `--limit <N>`，默认 `50`。
2. 调用 `mcp__expool__exp_list`，传 `limit=<N>`。

## 渲染要求

按 `acl`（`public` / `private` / `team:*`）分组展示，每组用紧凑表格：

| id8 | task_type 任务类型 | intent 意图 |
|---|---|---|

- `id8` 是 experience_id 前 8 位，便于后续 `/expool:get <id8>` 或 `/expool:revoke <id8>`
- `task_type` 含义：`claude-code-backfill` 历史回填、`auto-sync` 守护进程自动同步、`misc` 未分类
- `intent` 截断到 60 字符，超出加省略号
- 末尾给一行 **总计：N 条（M 条 public · K 条 private）**
