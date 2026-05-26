---
description: 开启自动上传：新 session 结束后自动归档到 private 库。
argument-hint: "[--sources claude-code,codex,hermes] [--interval 120]"
allowed-tools: [Bash, Read]
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

Enable the local automatic upload scheduler.

Run the bundled control script:

```bash
if command -v expool-plugin >/dev/null 2>&1; then
  expool-plugin auto on $ARGUMENTS
else
  bash "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/scripts/auto-upload.sh" start $ARGUMENTS
fi
```

If `$ARGUMENTS` is empty, use the safe defaults:

```bash
if command -v expool-plugin >/dev/null 2>&1; then
  expool-plugin auto on
else
  bash "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/scripts/auto-upload.sh" start
fi
```

Default behavior:

- sources: `claude-code,codex,hermes`
- interval: `120` seconds
- task: `auto-sync`
- acl: `private`

Do not print secrets. If the command reports that no credential is configured,
tell the user to run `/expool:bind` before enabling auto upload.
