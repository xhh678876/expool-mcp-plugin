---
description: 撤回（软删除）你自己上传过的一条经验。
argument-hint: "<id-or-8char-prefix>"
allowed-tools: [mcp__expool__exp_revoke]
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

Revoke an experience the caller previously uploaded.

Parse `$ARGUMENTS` as the experience id. If it is empty, ask the user
which experience to revoke and suggest running `/expool:list` first.

Call `mcp__expool__exp_revoke` with `experience_id=<that string>`.

On success print:

> ✅ revoked `<id8>` — server will purge within 24h.

On failure (e.g. id not found / not owned), surface the error.
