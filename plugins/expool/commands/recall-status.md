---
description: 查看自动召回是否开启，以及 Claude Code hook / Codex AGENTS 契约状态。
argument-hint: ""
allowed-tools: [Bash, Read]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

Show automatic recall status.

Run:

```bash
if command -v expool-plugin >/dev/null 2>&1; then
  expool-plugin recall status $ARGUMENTS
else
  bash "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/scripts/auto-recall.sh" status $ARGUMENTS
fi
```

Summarize:

- `claude_enabled`: Claude Code 是否会通过 UserPromptSubmit hook 自动召回
- `codex_enabled`: Codex 是否已经写入 AGENTS 自动召回契约
- `scope`: 默认召回范围，应该是 `personal`
- `top_k`: 每次注入几条经验

Do not print secrets.
