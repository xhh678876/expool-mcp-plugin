---
description: 撤回（软删除）你自己上传过的一条经验。
argument-hint: "<id-or-8char-prefix>"
allowed-tools: [mcp__expool__exp_revoke]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

Revoke an experience the caller previously uploaded.

Parse `$ARGUMENTS` as the experience id. If it is empty, ask the user
which experience to revoke and suggest running `/expool:list` first.

Call `mcp__expool__exp_revoke` with `experience_id=<that string>`.

On success print:

> ✅ revoked `<id8>` — server will purge within 24h.

On failure (e.g. id not found / not owned), surface the error.
