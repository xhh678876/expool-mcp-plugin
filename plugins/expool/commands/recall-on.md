---
description: 开启自动召回：Claude Code 每条任务消息前自动请求平台 RAG context；Codex 写入 AGENTS 契约要求先查再做。
argument-hint: "[--targets claude,codex] [--top-k 3] [--scope personal|project:<slug>]"
allowed-tools: [Bash, Read]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

Enable automatic recall.

Run:

```bash
if command -v expool-plugin >/dev/null 2>&1; then
  expool-plugin recall on $ARGUMENTS
else
  bash "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/scripts/auto-recall.sh" on $ARGUMENTS
fi
```

Default behavior:

- targets: `claude,codex`
- scope: `personal`
- top-k: `3`
- Claude Code: installs/enables a `UserPromptSubmit` recall hook.
- Codex: writes a managed block into `~/.codex/AGENTS.md`; Codex has no equivalent hook in this plugin, so this is an instruction contract.

Render the result compactly. Tell the user that future non-trivial tasks will
first request a platform-side RAG context pack before handling the task. If
they used `--scope project:<slug>`, mention that recall will search that
project pool's granted personal owners.
