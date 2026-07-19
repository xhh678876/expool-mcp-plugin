---
description: 查看自动上传后台日志。
argument-hint: ""
allowed-tools: [Bash, Read]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

Show recent automatic upload logs.

Run:

```bash
if command -v expool-plugin >/dev/null 2>&1; then
  expool-plugin auto logs $ARGUMENTS
else
  bash "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/scripts/auto-upload.sh" logs $ARGUMENTS
fi
```

Summarize the latest scheduler/upload activity compactly. If no log exists,
say that no background upload log has been written yet and suggest
`/expool:auto-tick --verbose` for a foreground progress pass.
