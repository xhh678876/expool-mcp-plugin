---
description: 关闭自动召回。
argument-hint: "[--targets claude,codex]"
allowed-tools: [Bash, Read]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

Disable automatic recall.

Run:

```bash
if command -v expool-plugin >/dev/null 2>&1; then
  expool-plugin recall off $ARGUMENTS
else
  bash "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/scripts/auto-recall.sh" off $ARGUMENTS
fi
```

Render the result compactly. Explain that manual `/expool:prep <task>` and
`/expool:search <query>` remain available.
