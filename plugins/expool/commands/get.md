---
description: 按 id 拉取一条经验卡片的完整内容。
argument-hint: "<id-or-8char-prefix>"
allowed-tools: [mcp__expool__exp_get]
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
