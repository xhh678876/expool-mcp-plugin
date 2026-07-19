---
description: 按 id 拉取一条经验卡片的完整内容。
argument-hint: "<id-or-8char-prefix>"
allowed-tools: [mcp__expool__exp_get]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

## 工作流

从 `$ARGUMENTS` 取出 id（完整或 8 位前缀均可），调用 `mcp__expool__exp_get`，
传 `experience_id=<id>`。

## 渲染要求

把结果分三段呈现：

1. **头部信息** — `experience_id`、`created_at`（创建时间）、`task_type`（任务分类）、
   `acl`（可见范围）、`publish_status`（`private` 仅自己 / `published` 已发布到社区）、
   `q_scalar`（质量评分）
2. **LiteCard 经验卡片** — `intent`（意图）、`preconditions`（前置条件）、
   `script_steps`（步骤，用编号列表）、`pitfalls`（坑）、`outcome`（结果）
3. **Trajectory 完整对话链** — 若有 `trajectory_url`，给出下载路径；
   否则注明"trajectory 已丢弃（上传时 no_trace=true）"

空字段直接跳过。**不要**贴原始 JSON。
