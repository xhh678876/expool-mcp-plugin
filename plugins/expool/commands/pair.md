---
description: 用门户生成的一次性配对码（expair_）绑定本机。推荐用法，比直接粘 API Key 安全。
argument-hint: "<expair_pairing_code>"
allowed-tools: [mcp__expool__expool_pair]
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

Bind this plugin with a portal-issued one-time pairing code.

Parse `$ARGUMENTS` as one pairing code token. It should start with
`expair_`.

Call `mcp__expool__expool_pair` with:

- `code`: the supplied token
- `verify`: true

Never echo the resulting API key. On success, show only the credential file
path and suggest `/expool:status`.

If no code is supplied, tell the user to open `/me/api-keys`, generate a
one-time plugin binding code, then run:

```text
/expool:pair expair_...
```
