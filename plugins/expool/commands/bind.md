---
description: 一次性配置 expool 凭据（API Key 或 agent_name+secret 两种形式）。
argument-hint: "<expk_api_key> or <agent_name secret>"
allowed-tools: [Bash, Read, mcp__expool__expool_status, mcp__expool__expool_bind, mcp__expool__expool_bind_api]
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

Help the user configure the plugin-owned expool credential.

First call `mcp__expool__expool_status`.

If `configured=true`, show the agent name, gateway, and credential file path.
Do not read or print the secret.

If the user supplied a single token that starts with `expk_`, call
`mcp__expool__expool_bind_api` with:

- `api_key`: the supplied token
- `verify`: true

Never echo the API key back to the user. On success, say where the credential
was written and suggest `/expool:status`.

If the user supplied both `agent_name` and `secret` in `$ARGUMENTS`, call
`mcp__expool__expool_bind` with:

- `agent_name`: the supplied agent name
- `secret`: the supplied secret
- `verify`: true

Never echo the secret back to the user. On success, say where the credential
was written and suggest `/expool:status`.

If the user did not provide an API key or secret, tell them the safer terminal
path is a one-time pairing code from `/me/api-keys`:

```text
/expool:pair expair_...
```

If they already copied an API key and prefer terminal binding:

```bash
# Fill this from the portal /me/api-keys panel, then run locally.
EXPOOL_API_KEY='expk_...' \
expool-plugin bind+api "$EXPOOL_API_KEY" \
  --base "${EXPOOL_BASE:-${EXP_BIND_BASE_URL:-https://expool.clawsii.com}}"
```

Then ask them to run `/expool:status` to verify. This avoids putting the
credential into the chat transcript.
