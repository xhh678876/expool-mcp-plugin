---
description: 立刻跑一次自动上传扫描（不等定时器到点）。
argument-hint: "[--dry-run] [--verbose] [--sources claude-code,codex]"
allowed-tools: [Bash, Read]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

Run one incremental automatic upload pass immediately.

Run:

```bash
if command -v expool-plugin >/dev/null 2>&1; then
  expool-plugin auto tick $ARGUMENTS
else
  bash "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/scripts/auto-upload.sh" tick $ARGUMENTS
fi
```

Use `--dry-run` when the user wants to preview what would be uploaded without
transmitting anything.

Use `--verbose` when the user wants foreground progress. Progress lines are
printed while each source/session is scanned; the final JSON summary still
contains uploaded/skipped/failed totals.

Render the result compactly: total uploaded, skipped, failed, and source-level
counts. If the command reports `no_credential`, tell the user to run
`/expool:bind`.
