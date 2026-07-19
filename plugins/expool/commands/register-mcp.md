---
description: 把 expool MCP server 注册到本机 agent 的 MCP 注册表。
argument-hint: "[--targets claude,codex,openclaw,hermes] [--force] [--dry-run]"
allowed-tools: [Bash, Read]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

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
