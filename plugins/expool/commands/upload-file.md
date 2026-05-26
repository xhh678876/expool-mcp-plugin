---
description: 上传指定路径的 trajectory 文件到 private 库。
argument-hint: "<absolute-path> [task-classifier]"
allowed-tools: [mcp__expool__exp_push_file]
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

Upload the trajectory file the user supplied.

Parse `$ARGUMENTS`:
- The **first** whitespace-delimited token is the file path. Expand `~` and
  any env vars before passing it through. The path MUST exist; if it does
  not, ask the user to confirm before guessing.
- The **rest** of `$ARGUMENTS` is the task classifier (kebab-case). If
  empty, infer from the file name or contents.

Then call `mcp__expool__exp_push_file` with:

- `file`: the parsed path
- `task`: classifier (default `misc`)
- `sensitivity`: "medium" unless the file obviously contains secrets/PII
- `no_trace`: false

On success, print ONE line:

> 📤 uploaded `<basename>` as `<id8>` (task=`<task>`) — `/expool:revoke <id8>` to revoke
