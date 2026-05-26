---
description: 把 expool MCP server 注册到本机 agent 的 MCP 注册表。
argument-hint: "[--targets claude,codex,openclaw,hermes] [--force] [--dry-run]"
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

Register this plugin's MCP server with local agent runtimes so they can
discover the `expool` MCP tools from their own registries.

Run the bundled registry script:

```bash
if command -v expool-plugin >/dev/null 2>&1; then
  expool-plugin install --mcp-only $ARGUMENTS
else
  bash "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/scripts/register-mcp.sh" $ARGUMENTS
fi
```

If `$ARGUMENTS` is empty, use the script defaults:

```bash
if command -v expool-plugin >/dev/null 2>&1; then
  expool-plugin install --mcp-only
else
  bash "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/scripts/register-mcp.sh"
fi
```

Useful options:

- `--targets claude,codex` registers only Claude Code and Codex.
- `--targets openclaw,hermes` writes OpenClaw / Hermes descriptors when their
  native MCP CLI is unavailable.
- `--copy` copies the server into `~/.<agent>/mcp-servers/expool/` before
  registration. This is the default.
- `--direct` registers the current plugin directory directly.
- `--force` removes an existing `expool` MCP server before re-adding it.
- `--dry-run` prints the registry actions without changing files.

Render the script output compactly. If a target falls back to a portable
descriptor, tell the user the exact descriptor path so they can wire that
runtime if it expects a different registry location.
