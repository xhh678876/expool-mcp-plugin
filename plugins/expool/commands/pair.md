---
description: 用门户生成的一次性配对码（expair_）绑定本机。推荐用法，比直接粘 API Key 安全。
argument-hint: "<expair_pairing_code>"
allowed-tools: [mcp__expool__expool_pair]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

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
